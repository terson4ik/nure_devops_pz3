#!/usr/bin/env python3
"""Запуск pipeline у Kubeflow Pipelines (multi-user, автентифікація через Dex)."""
import os
import re
import sys
import time
from http.cookiejar import DefaultCookiePolicy
from pathlib import Path
from urllib.parse import urlsplit

import kfp
import requests

HOST = os.getenv("KUBEFLOW_HOST", "http://localhost:8080")
USERNAME = os.getenv("KUBEFLOW_USER", "user@example.com")
PASSWORD = os.getenv("KUBEFLOW_PASSWORD", "12341234")
NAMESPACE = os.getenv("KUBEFLOW_NAMESPACE", "kubeflow-user-example-com")
PIPELINE_FILE = Path(
    os.getenv("PIPELINE_FILE", str(Path(__file__).with_name("iris_pipeline.yaml")))
)
TIMEOUT = int(os.getenv("RUN_TIMEOUT", "1800"))


def dex_session_cookies(host: str, username: str, password: str):
    """Проходить логін Dex/oauth2-proxy і повертає рядок cookie (або None, якщо захисту немає)."""
    with requests.Session() as session:
        # localhost по HTTP: дозволяємо відправляти Secure-cookie
        session.cookies.set_policy(DefaultCookiePolicy(secure_protocols=("http", "https")))

        resp = session.get(host, allow_redirects=True, timeout=30)
        resp.raise_for_status()
        if not resp.history:
            return None

        url = urlsplit(resp.url)
        if re.search(r"/auth$", url.path):
            login_url = url._replace(path=f"{url.path}/local").geturl()
        elif re.search(r"/auth/.*/login$", url.path):
            login_url = resp.url
        else:
            raise RuntimeError(f"Невідомий URL логіну Dex: {resp.url}")

        resp = session.post(
            login_url,
            data={"login": username, "password": password},
            allow_redirects=True,
            timeout=30,
        )
        if not resp.history:
            raise RuntimeError("Логін у Dex не вдався (перевірте логін/пароль)")
        return "; ".join(f"{c.name}={c.value}" for c in session.cookies)


def main() -> int:
    if not PIPELINE_FILE.exists():
        print(f"Немає файлу {PIPELINE_FILE}. Спочатку: python pipelines/iris_pipeline.py")
        return 2

    cookies = dex_session_cookies(HOST, USERNAME, PASSWORD)
    client = kfp.Client(host=f"{HOST}/pipeline", cookies=cookies, namespace=NAMESPACE)

    run = client.create_run_from_pipeline_package(
        pipeline_file=str(PIPELINE_FILE),
        arguments={},
        run_name=f"iris-run-{int(time.time())}",
        experiment_name="iris-experiment",
        namespace=NAMESPACE,
        enable_caching=False,
    )
    print(f"Run ID : {run.run_id}")
    print(f"UI     : {HOST}/_/pipeline/#/runs/details/{run.run_id}")

    result = client.wait_for_run_completion(run.run_id, timeout=TIMEOUT)
    state = str(result.state)
    print(f"Фінальний стан: {state}")
    return 0 if state == "SUCCEEDED" else 1


if __name__ == "__main__":
    sys.exit(main())

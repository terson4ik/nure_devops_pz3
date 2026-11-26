"""Навчання моделі Iris (виконується під час збірки Docker-образу)."""
import argparse
import json

import joblib
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="model.joblib")
    parser.add_argument("--n-estimators", type=int, default=100)
    parser.add_argument("--max-depth", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    iris = load_iris()
    x_train, x_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=args.seed, stratify=iris.target
    )
    clf = RandomForestClassifier(
        n_estimators=args.n_estimators, max_depth=args.max_depth, random_state=args.seed
    )
    clf.fit(x_train, y_train)
    accuracy = accuracy_score(y_test, clf.predict(x_test))

    joblib.dump({"model": clf, "classes": [str(c) for c in iris.target_names]}, args.out)
    print(json.dumps({"accuracy": round(float(accuracy), 4), "model_path": args.out}))


if __name__ == "__main__":
    main()

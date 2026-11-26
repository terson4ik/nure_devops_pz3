"""Kubeflow Pipeline: Iris -> навчання -> оцінка -> умовне передбачення."""
from pathlib import Path

from kfp import compiler, dsl
from kfp.dsl import ClassificationMetrics, Dataset, Input, Metrics, Model, Output

BASE_IMAGE = "python:3.12-slim"
PACKAGES = ["pandas==2.2.3", "scikit-learn==1.6.1", "joblib==1.4.2"]
DEFAULT_SAMPLES = [
    [5.1, 3.5, 1.4, 0.2],
    [6.7, 3.1, 4.7, 1.5],
    [6.3, 3.3, 6.0, 2.5],
]


@dsl.component(base_image=BASE_IMAGE, packages_to_install=PACKAGES)
def load_data(
    train_data: Output[Dataset],
    test_data: Output[Dataset],
    test_size: float = 0.2,
    seed: int = 42,
):
    """Завантажує датасет Iris та ділить його на train/test."""
    from sklearn.datasets import load_iris
    from sklearn.model_selection import train_test_split

    df = load_iris(as_frame=True).frame
    df.columns = [c.replace(" (cm)", "").replace(" ", "_") for c in df.columns]
    train_df, test_df = train_test_split(
        df, test_size=test_size, random_state=seed, stratify=df["target"]
    )
    train_df.to_csv(train_data.path, index=False)
    test_df.to_csv(test_data.path, index=False)
    train_data.metadata["rows"] = len(train_df)
    test_data.metadata["rows"] = len(test_df)
    print(f"train={len(train_df)} test={len(test_df)} columns={list(df.columns)}")


@dsl.component(base_image=BASE_IMAGE, packages_to_install=PACKAGES)
def train_model(
    train_data: Input[Dataset],
    model_out: Output[Model],
    n_estimators: int = 100,
    max_depth: int = 5,
    seed: int = 42,
):
    """Навчає RandomForestClassifier."""
    import joblib
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier

    df = pd.read_csv(train_data.path)
    x, y = df.drop(columns=["target"]), df["target"]
    clf = RandomForestClassifier(
        n_estimators=n_estimators, max_depth=max_depth, random_state=seed
    )
    clf.fit(x, y)
    joblib.dump(clf, model_out.path)
    model_out.metadata["framework"] = "scikit-learn"
    model_out.metadata["n_estimators"] = n_estimators
    print(f"Модель навчено: n_estimators={n_estimators}, max_depth={max_depth}")


@dsl.component(base_image=BASE_IMAGE, packages_to_install=PACKAGES)
def evaluate_model(
    test_data: Input[Dataset],
    model: Input[Model],
    metrics: Output[Metrics],
    cls_metrics: Output[ClassificationMetrics],
) -> float:
    """Оцінює модель на тестових даних, логує метрики."""
    import joblib
    import pandas as pd
    from sklearn.metrics import accuracy_score, confusion_matrix, f1_score

    df = pd.read_csv(test_data.path)
    x, y = df.drop(columns=["target"]), df["target"]
    clf = joblib.load(model.path)
    pred = clf.predict(x)

    accuracy = float(accuracy_score(y, pred))
    f1 = float(f1_score(y, pred, average="macro"))
    metrics.log_metric("accuracy", accuracy)
    metrics.log_metric("f1_macro", f1)
    cls_metrics.log_confusion_matrix(
        ["setosa", "versicolor", "virginica"], confusion_matrix(y, pred).tolist()
    )
    print(f"accuracy={accuracy:.4f} f1_macro={f1:.4f}")
    return accuracy


@dsl.component(base_image=BASE_IMAGE, packages_to_install=PACKAGES)
def predict(model: Input[Model], samples: list, predictions: Output[Dataset]):
    """Виконує передбачення для вхідних зразків."""
    import joblib
    import pandas as pd

    features = ["sepal_length", "sepal_width", "petal_length", "petal_width"]
    names = ["setosa", "versicolor", "virginica"]
    clf = joblib.load(model.path)
    x = pd.DataFrame(samples, columns=features)
    result = x.copy()
    result["predicted_class"] = [names[i] for i in clf.predict(x)]
    result.to_csv(predictions.path, index=False)
    print("=== PREDICTIONS ===")
    print(result.to_string(index=False))


@dsl.pipeline(
    name="iris-mlops-pipeline",
    description="Iris: load -> train -> evaluate -> predict (за умови accuracy >= порогу)",
)
def iris_pipeline(
    test_size: float = 0.2,
    n_estimators: int = 100,
    max_depth: int = 5,
    seed: int = 42,
    min_accuracy: float = 0.9,
    samples: list = DEFAULT_SAMPLES,
):
    data = load_data(test_size=test_size, seed=seed).set_display_name("Load data")
    trained = train_model(
        train_data=data.outputs["train_data"],
        n_estimators=n_estimators,
        max_depth=max_depth,
        seed=seed,
    ).set_display_name("Train model")
    evaluated = evaluate_model(
        test_data=data.outputs["test_data"],
        model=trained.outputs["model_out"],
    ).set_display_name("Evaluate model")

    with dsl.If(evaluated.output >= min_accuracy, name="accuracy-gate"):
        predict(model=trained.outputs["model_out"], samples=samples).set_display_name(
            "Predict"
        )


if __name__ == "__main__":
    target = Path(__file__).with_suffix(".yaml")
    compiler.Compiler().compile(pipeline_func=iris_pipeline, package_path=str(target))
    print(f"Pipeline скомпільовано: {target}")

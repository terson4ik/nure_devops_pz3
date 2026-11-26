"""REST API передбачення виду ірису."""
import os

import joblib
from fastapi import FastAPI
from pydantic import BaseModel, Field

MODEL_PATH = os.getenv("MODEL_PATH", "/srv/model.joblib")

bundle = joblib.load(MODEL_PATH)
model = bundle["model"]
classes = bundle["classes"]

app = FastAPI(title="Iris prediction API", version=os.getenv("APP_VERSION", "0.1.0"))


class IrisFeatures(BaseModel):
    sepal_length: float = Field(gt=0, examples=[5.1])
    sepal_width: float = Field(gt=0, examples=[3.5])
    petal_length: float = Field(gt=0, examples=[1.4])
    petal_width: float = Field(gt=0, examples=[0.2])


@app.get("/")
def root():
    return {"service": "iris-api", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict")
def predict(features: IrisFeatures):
    x = [[features.sepal_length, features.sepal_width, features.petal_length, features.petal_width]]
    proba = model.predict_proba(x)[0]
    idx = int(proba.argmax())
    return {
        "class_id": idx,
        "class_name": str(classes[idx]),
        "probability": round(float(proba[idx]), 4),
    }

"""Format d'erreur unique, celui que le mobile sait deja lire.

`ErrorMapper`, cote application, attend un corps `{"error": {"code", "message",
"details"}}` et se sert du **code** pour decider quoi faire — pas du message,
qui est destine aux humains et peut changer sans preavis. Toute erreur du
serveur passe donc par ici : une seule sortie, un seul format.
"""

from __future__ import annotations

from fastapi import Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: dict | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def error_body(code: str, message: str, details: dict | None = None) -> dict:
    body: dict = {"error": {"code": code, "message": message}}
    if details:
        body["error"]["details"] = details
    return body


async def api_error_handler(_: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=error_body(exc.code, exc.message, exc.details),
    )


# --- Raccourcis, pour que les routes lisent comme des phrases ---------------


def unauthorized(message: str = "Jeton absent ou invalide") -> ApiError:
    return ApiError(401, "unauthorized", message)


def forbidden(code: str, message: str) -> ApiError:
    return ApiError(403, code, message)


def not_found(message: str = "Ressource inconnue") -> ApiError:
    return ApiError(404, "not_found", message)


def conflict(code: str, message: str, details: dict | None = None) -> ApiError:
    return ApiError(409, code, message, details)


def unprocessable(code: str, message: str, details: dict | None = None) -> ApiError:
    return ApiError(422, code, message, details)

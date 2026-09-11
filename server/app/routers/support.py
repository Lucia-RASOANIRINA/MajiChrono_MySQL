"""Notifications, support client et audit des tables historiques du site."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.deps import current_account, require_role
from app.core.errors import not_found
from app.db import get_db
from app.models import (
    Account,
    ApiToken,
    ContactMessage,
    LoginAttempt,
    Notification,
    PasswordReset,
    ReclamationFile,
    Setting,
    UserRole,
)

router = APIRouter(tags=["support"])


class ContactBody(BaseModel):
    subject: str = Field(min_length=1, max_length=160)
    message: str = Field(min_length=1, max_length=10000)


class ReplyBody(BaseModel):
    reply: str = Field(min_length=1, max_length=10000)


class FileBody(BaseModel):
    filePath: str = Field(min_length=1, max_length=255)
    originalName: str = Field(min_length=1, max_length=255)
    mimeType: str = Field(min_length=1, max_length=80)
    sizeBytes: int = Field(ge=0)


class SettingBody(BaseModel):
    value: str | None = Field(default=None, max_length=10000)


@router.get("/notifications")
async def notifications(
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    rows = db.scalars(
        select(Notification)
        .where(Notification.user_id == account.id)
        .order_by(Notification.created_at.desc())
        .limit(100)
    ).all()
    return {"items": [row.to_json() for row in rows]}


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    row = db.scalar(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == account.id,
        )
    )
    if row is None:
        raise not_found("Notification inconnue")
    row.is_read = True
    db.commit()
    return row.to_json()


@router.post("/contact", status_code=201)
async def create_contact(
    body: ContactBody,
    db: Session = Depends(get_db),
    account: Account = Depends(current_account),
) -> dict:
    row = ContactMessage(
        client_id=account.id,
        subject=body.subject.strip(),
        message=body.message.strip(),
    )
    db.add(row)
    db.commit()
    return {"id": row.id, "status": row.status}


@router.get("/admin/contact")
async def list_contact(
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    rows = db.scalars(select(ContactMessage).order_by(ContactMessage.created_at.desc()).limit(100)).all()
    return {
        "items": [
            {
                "id": row.id,
                "clientId": row.client_id,
                "subject": row.subject,
                "message": row.message,
                "status": row.status,
                "adminReply": row.admin_reply,
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/admin/contact/{message_id}/reply")
async def reply_contact(
    message_id: int,
    body: ReplyBody,
    db: Session = Depends(get_db),
    admin: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    row = db.get(ContactMessage, message_id)
    if row is None:
        raise not_found("Message inconnue")
    now = datetime.now(timezone.utc)
    row.admin_reply = body.reply.strip()
    row.replied_by = admin.id
    row.replied_at = now
    row.updated_at = now
    row.status = "answered"
    db.add(
        Notification(
            user_id=row.client_id,
            type="support",
            title="Réponse du support",
            message=row.admin_reply,
            related_id=row.id,
        )
    )
    db.commit()
    return {"id": row.id, "status": row.status}


@router.get("/disputes/{dispute_id}/files")
async def list_reclamation_files(
    dispute_id: int,
    db: Session = Depends(get_db),
    _: Account = Depends(current_account),
) -> dict:
    rows = db.scalars(
        select(ReclamationFile)
        .where(ReclamationFile.reclamation_id == dispute_id)
        .order_by(ReclamationFile.created_at)
    ).all()
    return {
        "items": [
            {
                "id": row.id,
                "filePath": row.file_path,
                "originalName": row.original_name,
                "mimeType": row.mime_type,
                "sizeBytes": row.size_bytes,
                "createdAt": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }


@router.post("/disputes/{dispute_id}/files", status_code=201)
async def add_reclamation_file(
    dispute_id: int,
    body: FileBody,
    db: Session = Depends(get_db),
    _: Account = Depends(current_account),
) -> dict:
    row = ReclamationFile(
        reclamation_id=dispute_id,
        file_path=body.filePath,
        original_name=body.originalName,
        mime_type=body.mimeType,
        size_bytes=body.sizeBytes,
    )
    db.add(row)
    db.commit()
    return {"id": row.id, "reclamationId": dispute_id}


@router.get("/admin/system/audit")
async def system_audit(
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    return {
        "apiTokens": db.scalar(select(func.count()).select_from(ApiToken)) or 0,
        "loginAttempts": db.scalar(select(func.count()).select_from(LoginAttempt)) or 0,
        "passwordResets": db.scalar(select(func.count()).select_from(PasswordReset)) or 0,
        "settings": db.scalar(select(func.count()).select_from(Setting)) or 0,
        "notifications": db.scalar(select(func.count()).select_from(Notification)) or 0,
        "contactMessages": db.scalar(select(func.count()).select_from(ContactMessage)) or 0,
        "reclamationFiles": db.scalar(select(func.count()).select_from(ReclamationFile)) or 0,
    }


@router.get("/admin/settings")
async def list_settings(
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    rows = db.scalars(select(Setting).order_by(Setting.key_name)).all()
    return {
        "items": [
            {"key": row.key_name, "value": row.value, "updatedAt": row.updated_at.isoformat()}
            for row in rows
        ]
    }


@router.put("/admin/settings/{key}")
async def update_setting(
    key: str,
    body: SettingBody,
    db: Session = Depends(get_db),
    _: Account = Depends(require_role(UserRole.admin)),
) -> dict:
    row = db.get(Setting, key)
    if row is None:
        row = Setting(key_name=key, value=body.value)
        db.add(row)
    else:
        row.value = body.value
        row.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"key": row.key_name, "value": row.value}

<?php

namespace App\Exceptions;

use Exception;

/**
 * Format d'erreur unique du mobile : {"error": {"code","message","details?"}}.
 * Equivalent de server/app/core/errors.py.
 */
class ApiException extends Exception
{
    public readonly string $errorCode;

    public function __construct(
        public readonly int $statusCode,
        string $errorCode,
        string $message,
        public readonly ?array $details = null,
    ) {
        parent::__construct($message);
        $this->errorCode = $errorCode;
    }

    public function toResponse(): array
    {
        $error = ['code' => $this->errorCode, 'message' => $this->getMessage()];
        if ($this->details) {
            $error['details'] = $this->details;
        }

        return ['error' => $error];
    }

    public static function unauthorized(string $message = 'Jeton absent ou invalide'): self
    {
        return new self(401, 'unauthorized', $message);
    }

    public static function forbidden(string $code, string $message): self
    {
        return new self(403, $code, $message);
    }

    public static function notFound(string $message = 'Ressource inconnue'): self
    {
        return new self(404, 'not_found', $message);
    }

    public static function conflict(string $code, string $message, ?array $details = null): self
    {
        return new self(409, $code, $message, $details);
    }

    public static function unprocessable(string $code, string $message, ?array $details = null): self
    {
        return new self(422, $code, $message, $details);
    }

    public static function badGateway(string $code, string $message): self
    {
        return new self(502, $code, $message);
    }
}

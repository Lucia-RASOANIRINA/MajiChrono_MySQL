<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Media;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;

/**
 * Port de server/app/routers/media.py.
 */
class MediaController extends Controller
{
    public function store(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        $contentType = mb_strtolower(trim((string) $request->input('contentType')));
        $extension = explode('/', $contentType, 2)[1] ?? '';
        if ($extension === 'jpeg') {
            $extension = 'jpg';
        }
        if (! in_array($extension, config('majichrono.allowed_extensions'), true)) {
            throw ApiException::unprocessable('unsupported_type', "Format d'image non accepte");
        }

        $raw = (string) $request->input('imageBase64');
        if (str_starts_with(trim($raw), 'data:') && str_contains($raw, ',')) {
            $raw = explode(',', $raw, 2)[1];
        }

        $data = base64_decode($raw, true);
        if ($data === false) {
            throw ApiException::unprocessable('invalid_image', 'Image illisible');
        }
        if ($data === '') {
            throw ApiException::unprocessable('invalid_image', 'Image vide');
        }
        $maxBytes = config('majichrono.max_file_size');
        if (strlen($data) > $maxBytes) {
            throw ApiException::unprocessable('image_too_large', 'Image trop lourde', ['maxBytes' => $maxBytes]);
        }

        $media = Media::create([
            'account_id' => $account->id,
            'data' => $data,
            'content_type' => $contentType,
        ]);

        return response()->json(['id' => $media->id, 'url' => "/media/{$media->id}"], 201);
    }

    public function show(Request $request, string $mediaId)
    {
        CurrentAccount::resolve($request);

        $media = Media::find($mediaId);
        if ($media === null) {
            throw ApiException::notFound('Image inconnue');
        }

        return response($media->data, 200, ['Content-Type' => $media->content_type]);
    }
}

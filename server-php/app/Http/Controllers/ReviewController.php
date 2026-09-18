<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Delivery;
use App\Models\Review;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ReviewController extends Controller
{
    public function store(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($request->input('deliveryId'));
        if ($delivery === null) {
            throw ApiException::notFound('Course inconnue');
        }
        if ((string) $delivery->client_id !== (string) $account->id) {
            throw ApiException::forbidden('not_client', "Seul l'expediteur note la course");
        }
        if (! in_array($delivery->status, ['delivered', 'failed'], true)) {
            throw ApiException::unprocessable('not_delivered', "La course n'est pas encore remise", ['currentState' => $delivery->status]);
        }
        if ($delivery->driver_id === null) {
            throw ApiException::unprocessable('no_driver', 'Aucun livreur a evaluer');
        }

        $stars = (int) $request->input('stars');
        if ($stars < 1 || $stars > 5) {
            throw ApiException::unprocessable('invalid_stars', 'La note doit etre comprise entre 1 et 5');
        }
        $punctuality = $this->optionalRating($request->input('punctuality'));
        $service = $this->optionalRating($request->input('service'));
        $comment = $request->input('comment');
        if ($comment !== null && mb_strlen((string) $comment) > 2000) {
            throw ApiException::unprocessable('comment_too_long', 'Commentaire trop long');
        }

        $review = Review::firstOrNew(['delivery_id' => $delivery->id, 'rater_id' => $account->id]);
        $review->fill([
            'ratee_id' => $delivery->driver_id,
            'stars' => $stars,
            'punctuality' => $punctuality,
            'service' => $service,
            'comment' => $comment === null ? null : trim((string) $comment),
            'created_at' => $review->created_at ?: Carbon::now(),
        ]);
        $review->save();

        $average = Review::where('ratee_id', $delivery->driver_id)->avg('stars');
        Account::whereKey($delivery->driver_id)->update(['rating' => round((float) $average, 1)]);

        return response()->json($review->fresh()->payload(), 201);
    }

    public function show(Request $request, string $deliveryId)
    {
        $account = CurrentAccount::resolve($request);
        $review = Review::where('delivery_id', $deliveryId)->where('rater_id', $account->id)->first();
        if ($review === null) {
            throw ApiException::notFound('Aucun avis pour cette course');
        }

        return response()->json($review->payload());
    }

    private function optionalRating(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }
        $rating = (int) $value;
        if ($rating < 1 || $rating > 5) {
            throw ApiException::unprocessable('invalid_rating', 'La note doit etre comprise entre 1 et 5');
        }

        return $rating;
    }
}

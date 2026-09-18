<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Delivery;
use App\Models\Dispute;
use App\Models\DriverState;
use App\Models\ModerationLog;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AdminController extends Controller
{
    private function admin(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($account->role !== 'admin') {
            throw ApiException::forbidden('admin_required', "Accès réservé à l'administration");
        }

        return $account;
    }

    public function dashboard(Request $request)
    {
        $this->admin($request);
        $active = ['accepted', 'assigned', 'picking_up', 'picked_up', 'in_transit', 'awaiting_confirmation'];

        return response()->json([
            'pendingKyc' => Account::where('kyc_status', 'submitted')->count(),
            'activeDeliveries' => Delivery::whereIn('status', $active)->count(),
            'pendingDeliveries' => Delivery::where('status', 'pending')->count(),
            'onlineDrivers' => DriverState::where('online', true)->count(),
            'totalClients' => Account::where('role', 'client')->count(),
            'totalDrivers' => Account::where('role', 'driver')->count(),
            'openDisputes' => Dispute::whereIn('status', ['open', 'investigating'])->count(),
            'openIncidents' => DB::table('delivery_incidents')->where('resolution', 'open')->count(),
            'revenueToday' => Delivery::whereIn('status', ['delivered', 'failed'])
                ->whereDate('updated_at', Carbon::today())->sum('price_ariary'),
            'byStatus' => Delivery::query()->select('status', DB::raw('count(*) as total'))
                ->groupBy('status')->pluck('total', 'status'),
        ]);
    }

    public function fleet(Request $request)
    {
        $this->admin($request);
        $staleAt = Carbon::now()->subMinutes(3);
        $drivers = Account::where('role', 'driver')->orderBy('created_at')->get();
        $states = DriverState::whereIn('user_id', $drivers->pluck('id'))->get()->keyBy('user_id');

        return response()->json([
            'items' => $drivers->map(function (Account $driver) use ($states, $staleAt): array {
                $state = $states->get($driver->id);
                $fixedAt = $state?->fixed_at;

                return [
                    'driverId' => (string) $driver->id,
                    'displayName' => $driver->resolvedDisplayName(),
                    'phone' => $driver->phone,
                    'kycStatus' => $driver->kyc_status,
                    'suspended' => $driver->suspended_at !== null,
                    'online' => (bool) ($state?->online ?? false),
                    'lat' => $state?->lat,
                    'lng' => $state?->lng,
                    'fixedAt' => optional($fixedAt)->toIso8601String(),
                    'stale' => $fixedAt === null || $fixedAt->lt($staleAt),
                ];
            })->all(),
        ]);
    }

    public function users(Request $request)
    {
        $this->admin($request);
        $query = Account::query();
        if (in_array($request->query('role'), ['client', 'driver'], true)) {
            $query->where('role', $request->query('role'));
        }
        if (filled($request->query('q'))) {
            $term = '%'.trim((string) $request->query('q')).'%';
            $query->where(function ($builder) use ($term): void {
                $builder->where('display_name', 'like', $term)->orWhere('phone', 'like', $term);
            });
        }

        return response()->json([
            'items' => $query->latest('created_at')->limit(200)->get()->map(fn (Account $user): array => [
                'id' => (string) $user->id,
                'displayName' => $user->resolvedDisplayName(),
                'phone' => $user->phone,
                'role' => $user->role,
                'kycStatus' => $user->kyc_status,
                'rating' => $user->rating,
                'suspended' => $user->suspended_at !== null,
                'createdAt' => optional($user->created_at)->toIso8601String(),
            ])->all(),
        ]);
    }

    public function suspendDriver(Request $request, string $driverId)
    {
        $admin = $this->admin($request);
        $driver = Account::where('id', $driverId)->where('role', 'driver')->first();
        if ($driver === null) {
            throw ApiException::notFound('Livreur inconnu');
        }

        return response()->json($this->suspend($admin, $driver, $request));
    }

    public function suspendUser(Request $request, string $accountId)
    {
        $admin = $this->admin($request);
        $user = Account::find($accountId);
        if ($user === null || $user->role === 'admin' || (string) $user->id === (string) $admin->id) {
            throw ApiException::notFound('Compte inconnu');
        }

        return response()->json($this->suspend($admin, $user, $request));
    }

    public function moderation(Request $request)
    {
        $this->admin($request);

        return response()->json([
            'items' => ModerationLog::latest('decided_at')->get()->map(
                fn (ModerationLog $log): array => $log->payload()
            )->all(),
        ]);
    }

    private function suspend(Account $admin, Account $user, Request $request): array
    {
        $reason = trim((string) $request->input('reason'));
        if (mb_strlen($reason) < 10) {
            throw ApiException::unprocessable('reason_too_short', "Un motif d'au moins dix caracteres est exige", ['minLength' => 10]);
        }
        $suspend = filter_var($request->input('suspend'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($suspend === null) {
            throw ApiException::unprocessable('invalid_suspension', 'Decision invalide');
        }
        DB::transaction(function () use ($admin, $user, $suspend, $reason): void {
            $user->forceFill(['suspended_at' => $suspend ? Carbon::now() : null])->save();
            if ($suspend && $user->role === 'driver') {
                DriverState::where('user_id', $user->id)->update(['online' => false]);
            }
            ModerationLog::create([
                'id' => (string) Str::uuid(),
                'actor_id' => $admin->id,
                'subject_id' => $user->id,
                'action' => $suspend ? 'suspended' : 'unsuspended',
                'reason' => $reason,
                'decided_at' => Carbon::now(),
            ]);
        });

        return ['id' => (string) $user->id, 'suspended' => $suspend];
    }
}

<?php

namespace App\EventListener;

use App\Tenant\TenantContext;
use Symfony\Component\HttpKernel\Event\RequestEvent;

class TenantListener
{
    private TenantContext $tenantContext;

    public function __construct(TenantContext $tenantContext)
    {
        $this->tenantContext = $tenantContext;
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $session = $request->hasSession() ? $request->getSession() : null;

        if (!$session) {
            return;
        }

        // On extrait l'id_token OIDC stocké dans la session par OpenIDConnect.php
        $oidcToken = $session->get('oidcToken');

        if ($oidcToken) {
            $parts = explode('.', $oidcToken);
            if (count($parts) === 3) {
                $payload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[1])), true);

                if (isset($payload['network_id'])) {
                    $this->tenantContext->setNetworkId((string)$payload['network_id']);
                    return;
                }
            }
        }

        $this->tenantContext->setNetworkId('default');
    }
}
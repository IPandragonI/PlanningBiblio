<?php

namespace App\Tenant;

class TenantContext
{
    private ?string $networkId = null;
    private array $tenantConfig = [];

    public function __construct()
    {
        $tenantsPath = __DIR__ . '../../config/tenant.php';
        if (file_exists($tenantsPath)) {
            $this->tenantConfig = include $tenantsPath;
        }
    }

    public function setNetworkId(string $networkId): void
    {
        $this->networkId = $networkId;
    }

    public function getNetworkId(): ?string
    {
        return $this->networkId;
    }

    public function getCurrentTenantDatabaseParams(): ?array
    {
        if ($this->networkId && isset($this->tenantConfig[$this->networkId])) {
            return $this->tenantConfig[$this->networkId];
        }
        return null;
    }
}
<?php

namespace App\Tenant;

use Doctrine\DBAL\Connection;

class DynamicConnectionWrapper extends Connection
{
    private ?TenantContext $tenantContext = null;

    public function setTenantContext(TenantContext $tenantContext): void
    {
        $this->tenantContext = $tenantContext;
    }

    public function connect(): bool
    {
        if ($this->isConnected()) {
            return true;
        }

        if ($this->tenantContext) {
            $params = $this->tenantContext->getCurrentTenantDatabaseParams();
            if ($params) {
                $this->_params['dbname'] = $params['dbname'];
                $this->_params['user'] = $params['user'];
                $this->_params['password'] = $params['password'];
            }
        }

        return parent::connect();
    }
}
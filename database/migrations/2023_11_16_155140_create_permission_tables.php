<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\PermissionRegistrar;

class CreatePermissionTables extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        $tableNames = config('permission.table_names');
        $columnNames = config('permission.column_names');
        $teams = config('permission.teams');

        if (empty($tableNames)) {
            throw new \Exception('Error: config/permission.php not loaded. Run [php artisan config:clear] and try again.');
        }
        if ($teams && empty($columnNames['team_foreign_key'] ?? null)) {
            throw new \Exception('Error: team_foreign_key on config/permission.php not loaded. Run [php artisan config:clear] and try again.');
        }

        Schema::create($tableNames['permissions'], function (Blueprint $table) {
            $table->bigIncrements('id'); // permission id
            $table->string('name', 125);        // For MySQL 8.0 use string('name', 125);
            $table->string('guard_name', 125); // For MySQL 8.0 use string('guard_name', 125);
            $table->timestamps();

            $table->unique(['name', 'guard_name']);
        });

        Schema::create($tableNames['roles'], function (Blueprint $table) use ($teams, $columnNames) {
            $table->bigIncrements('id'); // role id
            if ($teams || config('permission.testing')) { // permission.testing is a fix for sqlite testing
                $table->unsignedBigInteger($columnNames['team_foreign_key'])->nullable();
                $table->index($columnNames['team_foreign_key'], 'roles_team_foreign_key_index');
            }
            $table->string('name', 125);        // For MySQL 8.0 use string('name', 125);
            $table->string('guard_name', 125); // For MySQL 8.0 use string('guard_name', 125);
            $table->timestamps();
            if ($teams || config('permission.testing')) {
                $table->unique([$columnNames['team_foreign_key'], 'name', 'guard_name']);
            } else {
                $table->unique(['name', 'guard_name']);
            }
        });

        Schema::create($tableNames['model_has_permissions'], function (Blueprint $table) use ($tableNames, $columnNames, $teams) {
            // CORRIGIDO: $pivotPermission -> $pivotPermissionKey
            $table->unsignedBigInteger(PermissionRegistrar::$pivotPermissionKey);

            $table->string('model_type');
            $table->unsignedBigInteger($columnNames['model_morph_key']);
            $table->index([$columnNames['model_morph_key'], 'model_type'], 'model_has_permissions_model_id_model_type_index');

            // CORRIGIDO: $pivotPermission -> $pivotPermissionKey
            $table->foreign(PermissionRegistrar::$pivotPermissionKey)
                ->references('id') // permission id
                ->on($tableNames['permissions'])
                ->onDelete('cascade');
            if ($teams) {
                $table->unsignedBigInteger($columnNames['team_foreign_key']);
                $table->index($columnNames['team_foreign_key'], 'model_has_permissions_team_foreign_key_index');

                // CORRIGIDO: $pivotPermission -> $pivotPermissionKey
                $table->primary([$columnNames['team_foreign_key'], PermissionRegistrar::$pivotPermissionKey, $columnNames['model_morph_key'], 'model_type'],
                    'model_has_permissions_permission_model_type_primary');
            } else {
                // CORRIGIDO: $pivotPermission -> $pivotPermissionKey
                $table->primary([PermissionRegistrar::$pivotPermissionKey, $columnNames['model_morph_key'], 'model_type'],
                    'model_has_permissions_permission_model_type_primary');
            }

        });

        Schema::create($tableNames['model_has_roles'], function (Blueprint $table) use ($tableNames, $columnNames, $teams) {
            // CORRIGIDO: $pivotRole -> $pivotRoleKey
            $table->unsignedBigInteger(PermissionRegistrar::$pivotRoleKey);

            $table->string('model_type');
            $table->unsignedBigInteger($columnNames['model_morph_key']);
            $table->index([$columnNames['model_morph_key'], 'model_type'], 'model_has_roles_model_id_model_type_index');

            // CORRIGIDO: $pivotRole -> $pivotRoleKey
            $table->foreign(PermissionRegistrar::$pivotRoleKey)
                ->references('id') // role id
                ->on($tableNames['roles'])
                ->onDelete('cascade');
            if ($teams) {
                $table->unsignedBigInteger($columnNames['team_foreign_key']);
                $table->index($columnNames['team_foreign_key'], 'model_has_roles_team_foreign_key_index');

                // CORRIGIDO: $pivotRole -> $pivotRoleKey
                $table->primary([$columnNames['team_foreign_key'], PermissionRegistrar::$pivotRoleKey, $columnNames['model_morph_key'], 'model_type'],
                    'model_has_roles_role_model_type_primary');
            } else {
                // CORRIGIDO: $pivotRole -> $pivotRoleKey
                $table->primary([PermissionRegistrar::$pivotRoleKey, $columnNames['model_morph_key'], 'model_type'],
                    'model_has_roles_role_model_type_primary');
            }
        });

        Schema::create($tableNames['role_has_permissions'], function (Blueprint $table) use ($tableNames) {
            // CORRIGIDO: $pivotPermission -> $pivotPermissionKey
            $table->unsignedBigInteger(PermissionRegistrar::$pivotPermissionKey);
            // CORRIGIDO: $pivotRole -> $pivotRoleKey
            $table->unsignedBigInteger(PermissionRegistrar::$pivotRoleKey);

            // CORRIGIDO: $pivotPermission -> $pivotPermissionKey
            $table->foreign(PermissionRegistrar::$pivotPermissionKey)
                ->references('id') // permission id
                ->on($tableNames['permissions'])
                ->onDelete('cascade');

            // CORRIGIDO: $pivotRole -> $pivotRoleKey
            $table->foreign(PermissionRegistrar::$pivotRoleKey)
                ->references('id') // role id
                ->on($tableNames['roles'])
                ->onDelete('cascade');

            // CORRIGIDO: $pivotPermission e $pivotRole
            $table->primary([PermissionRegistrar::$pivotPermissionKey, PermissionRegistrar::$pivotRoleKey], 'role_has_permissions_permission_id_role_id_primary');
        });

        app('cache')
            ->store(config('permission.cache.store') != 'default' ? config('permission.cache.store') : null)
            ->forget(config('permission.cache.key'));
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        $tableNames = config('permission.table_names');

        if (empty($tableNames)) {
            throw new \Exception('Error: config/permission.php not found and defaults could not be merged. Please publish the package configuration before proceeding, or drop the tables manually.');
        }

        Schema::drop($tableNames['role_has_permissions']);
        Schema::drop($tableNames['model_has_roles']);
        Schema::drop($tableNames['model_has_permissions']);
        Schema::drop($tableNames['roles']);
        Schema::drop($tableNames['permissions']);
    }
}

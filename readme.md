<p align="center">
<h1 align="center">DP-RealMoney</h1>

<img width="960" height="auto" align="center" alt="DP-Banking Logo" src="Images (Can Remove it if u want)/Miniaturas YT.png" />

</p>

<div align="center">

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![FiveM](https://img.shields.io/badge/FiveM-Script-important)](https://fivem.net/)
[![QBCore](https://img.shields.io/badge/QBCore-Framework-success)](<[https://qbcore-framework.github.io/qb-docs/](https://github.com/qbcore-framework)>)

</div>

<h2 align="center"> 📝 Descripción General</h2>
Este script transforma el dinero virtual de QBCore (Efectivo, Dinero Negro y Criptomonedas) en **ítems físicos** dentro del inventario del jugador.

A diferencia de otros scripts de "Cash as Item", **DP-REALMONEY** incluye una lógica de sincronización inteligente que respeta el orden de tu inventario.

## 🌟 Características Principales

- **🛠️ Fix de Slots (¡Novedad!):** El script calcula matemáticamente la diferencia de dinero en lugar de borrar y recrear el ítem.
  - _Resultado:_ **El dinero NUNCA se mueve de sitio** cuando compras o recibes cambio. Se queda fijo en el slot donde lo pusiste.
- **🇪🇸 100% Español:** Todo el código, comentarios, logs y notificaciones están traducidos y explicados para facilitar la configuración.
- **⚡ Optimizado:** Sistema de "bloqueo de sincronización" para evitar duplicaciones o bucles infinitos al actualizar el dinero.
- **🔔 Notificaciones Nativas:** Utiliza el sistema nativo de `qb-core` (sin dependencias de HUDs externos).

## 📦 Dependencias

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [qb-inventory](https://github.com/qbcore-framework/qb-inventory) (o inventarios compatibles como ox_inventory/qs-inventory)

## 🔧 Instalación

1.  Descarga y coloca la carpeta `dp-realmoney` (o el nombre que le hayas puesto) en tu directorio `resources`.
2.  Asegúrate de tener los ítems configurados en tu `qb-core/shared/items.lua` (normalmente `cash`, `black_money`, `crypto`).
3.  Añade `ensure dp-realmoney` en tu `server.cfg`.
4.  Reinicia el servidor.

## 💻 Comandos

El script incluye comandos útiles para verificar tus saldos rápidamente:

| Comando       | Descripción                                                    |
| :------------ | :------------------------------------------------------------- |
| `/blackmoney` | Muestra una notificación con tu saldo actual de dinero negro.  |
| `/crypto`     | Muestra una notificación con tu saldo actual de criptomonedas. |

## ⚙️ Configuración Técnica (Developers)

Si necesitas integrar este sistema con otros scripts (como un sistema de robos o tiendas personalizadas), el script exporta las siguientes funciones seguras:

### Actualizar Ítem (Sincronización forzada)

```lua
exports['dp-realmoney']:UpdateItem(source, 'cash')
-- Tipos válidos: 'cash', 'black_money', 'crypto'
```

### Gestionar Transacción (Añadir/Quitar dinero + Sincronizar)

```lua
--- Añadir dinero
exports['dp-realmoney']:UpdateCash(source, 'cash', 100, 'add')

-- Quitar dinero
exports['dp-realmoney']:UpdateCash(source, 'cash', 50, 'remove')
```

### 🧩 Integración Avanzada (Opcional)

Si utilizas qb-multicharacter o qb-inventory, puedes añadir los siguientes códigos para asegurar una sincronización perfecta al entrar al servidor o mover ítems.

1. QB-Multicharacter
   Abre server/main.lua y busca el evento qb-multicharacter:server:loadUserData (aprox. línea 89). Añade la llamada al export justo después de cargar los datos:

```lua
RegisterNetEvent('qb-multicharacter:server:loadUserData', function(cData)
    local src = source
    if QBCore.Player.Login(src, cData.citizenid) then
        repeat
            Wait(10)
        until hasDonePreloading[src]
        print('^2[qb-core]^7 ' .. GetPlayerName(src) .. ' (Citizen ID: ' .. cData.citizenid .. ') has successfully loaded!')
        QBCore.Commands.Refresh(src)
        loadHouseData(src)

        -- [[ INICIO INTEGRACIÓN DP-REALMONEY ]] --
        if GetResourceState("DP-RealMoney") ~= 'missing' then
            exports['DP-RealMoney']:UpdateItem(src, 'cash')
            exports['DP-RealMoney']:UpdateItem(src, 'black_money')
            exports['DP-RealMoney']:UpdateItem(src, 'crypto')
        end
        -- [[ FIN INTEGRACIÓN ]] --

        if Config.SkipSelection then
            local coords = json.decode(cData.position)
            TriggerClientEvent('qb-multicharacter:client:spawnLastLocation', src, coords, cData)
        else
            if GetResourceState('qb-apartments') == 'started' then
                TriggerClientEvent('apartments:client:setupSpawnUI', src, cData)
            else
                TriggerClientEvent('qb-spawn:client:setupSpawns', src, cData, false, nil)
                TriggerClientEvent('qb-spawn:client:openUI', src, true)
            end
        end
        TriggerEvent("qb-log:server:CreateLog", "joinleave", "Loaded", "green", "**" .. GetPlayerName(src) .. "** (<@" .. (QBCore.Functions.GetIdentifier(src, 'discord'):gsub("discord:", "") or "unknown") .. "> |  ||" .. (QBCore.Functions.GetIdentifier(src, 'ip') or 'undefined') .. "|| | " .. (QBCore.Functions.GetIdentifier(src, 'license') or 'undefined') .. " | " .. cData.citizenid .. " | " .. src .. ") loaded..")
    end
end)
```

2. QB-Inventory
   Para que el dinero se actualice correctamente al robar, dar o tirar ítems, realiza los siguientes cambios:

A) Sincronizar al Abrir Inventario Ajeno (server/functions.lua) Busca la función OpenInventoryById (aprox. línea 500):

```lua
function OpenInventoryById(source, targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not QBPlayer or not TargetPlayer then return end

    -- [[ INICIO INTEGRACIÓN ]] --
    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateItem(source, 'cash')
        exports['DP-RealMoney']:UpdateItem(source, 'black_money')
        exports['DP-RealMoney']:UpdateItem(source, 'crypto')

        exports['DP-RealMoney']:UpdateItem(targetId, 'cash')
        exports['DP-RealMoney']:UpdateItem(targetId, 'black_money')
        exports['DP-RealMoney']:UpdateItem(targetId, 'crypto')
    end
    -- [[ FIN INTEGRACIÓN ]] --

    if Player(targetId).state.inv_busy then CloseInventory(targetId) end
    local playerItems = QBPlayer.PlayerData.items
    local targetItems = TargetPlayer.PlayerData.items
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = GetPlayerName(targetId),
        maxweight = Config.MaxWeight,
        slots = Config.MaxSlots,
        inventory = targetItems
    }
    Wait(1500)
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('qb-inventory:client:openInventory', source, playerItems, formattedInventory)
end
```

B) Sincronizar al Tirar al Suelo (server/main.lua) Busca el callback qb-inventory:server:createDrop (aprox. línea 282):

```lua
QBCore.Functions.CreateCallback('qb-inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then

        -- [[ INICIO INTEGRACIÓN ]] --
        if GetResourceState("DP-RealMoney") ~= 'missing' then
            exports['DP-RealMoney']:UpdateCash(src, item.name, item.amount, 'remove')
        end
        -- [[ FIN INTEGRACIÓN ]] --

        if item.type == 'weapon' then checkWeapon(src, item) end
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId
        if not Drops[newDropId] then
            Drops[newDropId] = {
                name = newDropId,
                label = 'Drop',
                items = { item },
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = true
            }
            TriggerClientEvent('qb-inventory:client:setupDropTarget', -1, dropId)
        else
            table.insert(Drops[newDropId].items, item)
        end
        cb(dropId)
    else
        cb(false)
    end
end)
```

C) Sincronizar al Dar Ítem (server/main.lua) Busca el callback qb-inventory:server:giveItem (aprox. línea 379):

```lua
QBCore.Functions.CreateCallback('qb-inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(source)

    local Target = QBCore.Functions.GetPlayer(target)
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local targetPed = GetPlayerPed(target)

    local pCoords = GetEntityCoords(playerPed)
    local tCoords = GetEntityCoords(targetPed)
    if #(pCoords - tCoords) > 5 then
        cb(false)
        return
    end

    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        cb(false)
        return
    end

    local hasItem = HasItem(source, item)
    if not hasItem then
        cb(false)
        return
    end

    local itemAmount = GetItemByName(source, item).amount
    if itemAmount <= 0 then
        cb(false)
        return
    end

    local giveAmount = tonumber(amount)
    if giveAmount > itemAmount then
        cb(false)
        return
    end

    local removeItem = RemoveItem(source, item, giveAmount, slot, 'Item given to ID #' .. target)
    if not removeItem then
        cb(false)
        return
    end

    local giveItem = AddItem(target, item, giveAmount, false, info, 'Item given from ID #' .. source)
    if not giveItem then
        cb(false)
        return
    end

    if itemInfo.type == 'weapon' then checkWeapon(source, item) end

    -- [[ INICIO INTEGRACIÓN ]] --
    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateCash(source, item, giveAmount, 'remove')
    end

    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateCash(target, item, giveAmount, 'add')
    end
    -- [[ FIN INTEGRACIÓN ]] --

    TriggerClientEvent('qb-inventory:client:giveAnim', source)
    TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('qb-inventory:client:giveAnim', target)
    TriggerClientEvent('qb-inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)

    if Player(target).state.inv_busy then TriggerClientEvent('qb-inventory:client:updateInventory', target) end

    cb(true)
end)
```

D) Sincronizar al Mover/Stackear (server/main.lua) Busca el evento qb-inventory:server:SetInventoryData (aprox. línea 500):

```lua
RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    if toInventory:find('shop-') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)

    local fromItem = getItem(fromInventory, src, fromSlot)
    local toItem = getItem(toInventory, src, toSlot)

    if fromItem then
        if not toItem and toAmount > fromItem.amount then return end
        if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end
        local fromId = getIdentifier(fromInventory, src)
        local toId = getIdentifier(toInventory, src)

        if toItem and fromItem.name == toItem.name then
            if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item') then
                AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')

                -- [[ INICIO INTEGRACIÓN ]] --
                if GetResourceState("DP-RealMoney") ~= 'missing' then
                    exports['DP-RealMoney']:UpdateCash(fromId, fromItem, toAmount, 'remove')
                    exports['DP-RealMoney']:UpdateCash(toId, toItem, toAmount, 'add')
                end
                -- [[ FIN INTEGRACIÓN ]] --

            end
        elseif not toItem and toAmount < fromAmount then
            if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item') then
                AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item')

                -- [[ INICIO INTEGRACIÓN ]] --
                if GetResourceState("DP-RealMoney") ~= 'missing' then
                    exports['DP-RealMoney']:UpdateCash(fromId, fromItem, toAmount, 'remove')
                    exports['DP-RealMoney']:UpdateCash(toId, fromItem, toAmount, 'add')
                end
                -- [[ FIN INTEGRACIÓN ]] --

            end

        else
            if toItem then
                if RemoveItem(fromId, fromItem.name, fromAmount, fromSlot, 'swapped item') and RemoveItem(toId, toItem.name, toAmount, toSlot, 'swapped item') then
                    AddItem(toId, fromItem.name, fromAmount, toSlot, fromItem.info, 'swapped item')
                    AddItem(fromId, toItem.name, toAmount, fromSlot, toItem.info, 'swapped item')

                    -- [[ INICIO INTEGRACIÓN ]] --
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem, fromAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, toItem, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, fromItem, fromAmount, 'add')
                        exports['DP-RealMoney']:UpdateCash(fromId, toItem, toAmount, 'add')
                    end
                    -- [[ FIN INTEGRACIÓN ]] --

                end
            else
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item') then
                    AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item')

                    -- [[ INICIO INTEGRACIÓN ]] --
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, fromItem, toAmount, 'add')
                    end
                    -- [[ FIN INTEGRACIÓN ]] --

                end
            end
        end
    end
end)
```

### 📜 Créditos

Autor: DP-Scripts
Versión: 1.1.0

```

```

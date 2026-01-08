local QBCore = exports['qb-core']:GetCoreObject()
local BloqueosDeSincronizacion = {} -- Evita que el script se vuelva loco actualizando dos veces a la vez

--[[ ===================================================== ]] --
--[[                FUNCIONES DE UTILIDAD                  ]] --
--[[ ===================================================== ]] --

--- Obtiene el nombre limpio del ítem (convierte a minúsculas)
--- @param item: El objeto o nombre del item
local function ObtenerNombreLimpio(item)
    if type(item) == 'string' and item ~= nil then
        return item:lower()
    elseif type(item) == 'table' and item.name ~= nil then
        return item.name:lower()
    end
    return nil
end

--- Cuenta cuánto dinero físico (en ítems) tiene el jugador realmente
--- @param itemsInventario: La tabla de ítems del jugador
--- @param tipoDinero: 'cash', 'black_money', etc.
local function CalcularDineroFisico(itemsInventario, tipoDinero)
    local cantidadTotal = 0
    for _, item in pairs(itemsInventario) do
        if ObtenerNombreLimpio(item) == tipoDinero then
            cantidadTotal = cantidadTotal + (item.amount or 0)
        end
    end
    return cantidadTotal
end

--[[ ===================================================== ]] --
--[[                  LÓGICA DEL NÚCLEO                    ]] --
--[[ ===================================================== ]] --

--- La función principal: Compara la Base de Datos con el Inventario y corrige las diferencias
--- (Incluye el arreglo para que los ítems no salten de slot)
local function SincronizarInventario(idJugador, tipoDinero)
    local Jugador = QBCore.Functions.GetPlayer(idJugador)
    if not Jugador then
        return false
    end

    -- Filtro de seguridad: Solo aceptamos estos tipos de dinero
    if not (tipoDinero == 'cash' or tipoDinero == 'black_money' or tipoDinero == 'crypto') then
        return false
    end

    -- Si el jugador ya se está sincronizando, paramos para no duplicar
    if BloqueosDeSincronizacion[idJugador] then
        return false
    end

    BloqueosDeSincronizacion[idJugador] = true -- Activamos el candado

    -- 1. DATOS VIRTUALES: ¿Cuánto dice la base de datos que tienes?
    local dineroEnBaseDatos = Jugador.Functions.GetMoney(tipoDinero)
    if dineroEnBaseDatos < 0 then
        dineroEnBaseDatos = 0
    end

    -- 2. DATOS FÍSICOS: ¿Cuánto dinero tienes realmente en los bolsillos?
    local itemsInventario = Jugador.PlayerData.items
    local dineroEnBolsillos = CalcularDineroFisico(itemsInventario, tipoDinero)

    -- 3. CÁLCULO: ¿Falta o sobra dinero?
    local diferencia = dineroEnBaseDatos - dineroEnBolsillos

    -- 4. CORRECCIÓN: Ajustamos solo lo necesario
    if diferencia > 0 then
        -- Tienes más dinero en el banco/BD que en el bolsillo: TE DAMOS la diferencia
        Jugador.Functions.AddItem(tipoDinero, diferencia, nil, nil, 'Sincronizacion-Dinero-Item')
    elseif diferencia < 0 then
        -- Tienes menos dinero en BD que en el bolsillo: TE QUITAMOS el sobrante
        -- (Usamos math.abs para convertir el número negativo a positivo para la función Remove)
        Jugador.Functions.RemoveItem(tipoDinero, math.abs(diferencia))
    end

    BloqueosDeSincronizacion[idJugador] = nil -- Quitamos el candado
end

--- Función para forzar la sincronización manualmente (usada por otros scripts)
local function ForzarSincronizacion(idJugador, tipoDinero)
    if BloqueosDeSincronizacion[idJugador] then
        return
    end
    if not (tipoDinero == 'cash' or tipoDinero == 'black_money' or tipoDinero == 'crypto') then
        return
    end

    SincronizarInventario(idJugador, tipoDinero)
end
exports('UpdateItem', ForzarSincronizacion) -- Mantenemos 'UpdateItem' para compatibilidad externa

--- Función para gestionar pagos o cobros y sincronizar al momento
local function GestionarTransaccion(idJugador, item, cantidad, accion)
    local Jugador = QBCore.Functions.GetPlayer(idJugador)
    if not Jugador then
        return
    end

    local nombreItem = ObtenerNombreLimpio(item)
    if not (nombreItem == 'cash' or nombreItem == 'black_money' or nombreItem == 'crypto') then
        return
    end

    if BloqueosDeSincronizacion[idJugador] then
        return
    end
    BloqueosDeSincronizacion[idJugador] = true -- Candado temporal

    local dineroActual = Jugador.Functions.GetMoney(nombreItem)

    if accion == "add" then
        if cantidad > 0 then
            -- Añadimos dinero a la BD y luego sincronizamos el ítem
            Jugador.Functions.AddMoney(nombreItem, cantidad, 'actualizacion-dinero-' .. nombreItem)
            SincronizarInventario(idJugador, nombreItem)
        end
    elseif accion == "remove" then
        if cantidad > 0 and dineroActual >= cantidad then
            -- Quitamos dinero de la BD y luego sincronizamos el ítem
            Jugador.Functions.RemoveMoney(nombreItem, cantidad, 'actualizacion-dinero-' .. nombreItem)
            SincronizarInventario(idJugador, nombreItem)
        end
    end

    BloqueosDeSincronizacion[idJugador] = nil -- Liberar candado
end
exports('UpdateCash', GestionarTransaccion) -- Mantenemos 'UpdateCash' para compatibilidad externa

--[[ ===================================================== ]] --
--[[              EVENTOS DEL SERVIDOR                     ]] --
--[[ ===================================================== ]] --

-- Detecta cuando QBCore cambia el dinero de un jugador
RegisterNetEvent("QBCore:Server:OnMoneyChange", function(source, tipoDinero, cantidad, set, razon)
    if BloqueosDeSincronizacion[source] then
        return
    end

    -- Si cambia el banco, a veces QBCore toca el efectivo, así que revisamos el cash por si acaso
    if tipoDinero == 'bank' then
        ForzarSincronizacion(source, 'cash')
    else
        ForzarSincronizacion(source, tipoDinero)
    end
end)

-- Al arrancar el script, verifica que la base de datos esté bien configurada
AddEventHandler('onResourceStart', function(recurso)
    if recurso == GetCurrentResourceName() then
        if not QBCore.Config.Money.MoneyTypes['black_money'] then
            print("^1[" .. GetCurrentResourceName() .. "] - ERROR - Falta 'black_money' en 'qb-core/config.lua'.^7")
        else
            -- Revisa todos los jugadores para asegurar que tengan la cuenta de dinero negro
            local resultadoSQL = MySQL.Sync.fetchAll("SELECT * FROM players")
            if type(resultadoSQL) == 'table' and #resultadoSQL > 0 then
                for _, datos in pairs(resultadoSQL) do
                    local listaDinero = json.decode(datos.money)
                    if not listaDinero['black_money'] then
                        listaDinero['black_money'] = 0
                        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?',
                            {json.encode(listaDinero), datos.citizenid})
                    end
                end
            end
        end
    end
end)

--[[ ===================================================== ]] --
--[[                     COMANDOS                          ]] --
--[[ ===================================================== ]] --

-- Comando: /blackmoney (Ver dinero negro)
QBCore.Commands.Add('blackmoney', 'Ver saldo de dinero negro', {}, false, function(source, _)
    local Jugador = QBCore.Functions.GetPlayer(source)
    local cantidad = Jugador.PlayerData.money.black_money or 0

    QBCore.Functions.Notify(source, 'Tienes ' .. cantidad .. ' de dinero negro', 'primary', 5000)
end)

-- AI建造师状态图
-- 定义角色的动画状态和转换

require("stategraphs/commonstates")

local actionhandlers = {
    ActionHandler(ACTIONS.PICKUP, "pickup"),
    ActionHandler(ACTIONS.BUILD, "build"),
    ActionHandler(ACTIONS.CHOP, "chop"),
    ActionHandler(ACTIONS.MINE, "mine"),
    ActionHandler(ACTIONS.PICK, "pick"),
    ActionHandler(ACTIONS.HAMMER, "hammer"),
    ActionHandler(ACTIONS.WALKTO, "moving"),
}

local events = {
    CommonHandlers.OnLocomote(true, false),
    CommonHandlers.OnSleep(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnAttack(),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHitWhileInvincible(),
    
    -- 自定义事件
    EventHandler("doaction", function(inst, data)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
            local action = data.action
            if action.action == ACTIONS.BUILD then
                inst.sg:GoToState("build", action)
            elseif action.action == ACTIONS.CHOP then
                inst.sg:GoToState("chop", action)
            elseif action.action == ACTIONS.MINE then
                inst.sg:GoToState("mine", action)
            elseif action.action == ACTIONS.PICK then
                inst.sg:GoToState("pick", action)
            elseif action.action == ACTIONS.HAMMER then
                inst.sg:GoToState("hammer", action)
            end
        end
    end),
    
    EventHandler("think", function(inst)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("think")
        end
    end),
    
    EventHandler("talk", function(inst, data)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("talk")
        end
    end),
}

local states = {
    -- 基础状态
    State{
        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,
        
        events = {
            EventHandler("animover", function(inst)
                if math.random() < 0.1 then
                    inst.sg:GoToState("think")
                end
            end),
        },
    },
    
    -- 移动状态
    State{
        name = "moving",
        tags = {"moving", "canrotate"},
        
        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_loop", true)
        end,
        
        timeline = {
            TimeEvent(7*FRAMES, function(inst) 
                PlayFootstep(inst) 
            end),
            TimeEvent(15*FRAMES, function(inst) 
                PlayFootstep(inst) 
            end),
        },
        
        events = {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("moving") 
            end),
        },
        
        onexit = function(inst)
            inst.components.locomotor:Stop()
        end,
    },
    
    -- 思考状态
    State{
        name = "think",
        tags = {"thinking", "canrotate"},
        
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("research", false)
            
            -- 显示思考特效
            if math.random() < 0.5 then
                local fx = SpawnPrefab("electric_spark")
                if fx then
                    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
            end
        end,
        
        events = {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle") 
            end),
        },
    },
    
    -- 说话状态
    State{
        name = "talk",
        tags = {"talking", "canrotate"},
        
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("talk", false)
        end,
        
        events = {
            EventHandler("animover", function(inst) 
                inst.sg:GoToState("idle") 
            end),
        },
    },
    
    -- 建造状态
    State{
        name = "build",
        tags = {"building", "working", "busy"},
        
        onenter = function(inst, action)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("build_pre")
            inst.sg.statemem.action = action
        end,
        
        timeline = {
            TimeEvent(10*FRAMES, function(inst)
                inst.AnimState:PlayAnimation("build_loop", true)
            end),
            
            TimeEvent(20*FRAMES, function(inst)
                -- 建造音效
                inst.SoundEmitter:PlaySound("dontstarve/common/place_structure_stone")
            end),
        },
        
        events = {
            EventHandler("animover", function(inst)
                inst.AnimState:PlayAnimation("build_pst")
                inst.sg:GoToState("build_finish")
            end),
        },
        
        onexit = function(inst)
            -- 执行建造动作
            if inst.sg.statemem.action then
                inst:PerformBufferedAction()
            end
        end,
    },
    
    State{
        name = "build_finish",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.AnimState:PlayAnimation("build_pst")
        end,
        
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    
    -- 砍伐状态
    State{
        name = "chop",
        tags = {"chopping", "working", "busy"},
        
        onenter = function(inst, action)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("chop_pre")
            inst.sg.statemem.action = action
        end,
        
        timeline = {
            TimeEvent(6*FRAMES, function(inst)
                inst.AnimState:PlayAnimation("chop_loop", true)
            end),
            
            TimeEvent(12*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/use_axe_tree")
            end),
        },
        
        events = {
            EventHandler("animover", function(inst)
                inst.AnimState:PlayAnimation("chop_pst")
                inst.sg:GoToState("chop_finish")
            end),
        },
        
        onexit = function(inst)
            if inst.sg.statemem.action then
                inst:PerformBufferedAction()
            end
        end,
    },
    
    State{
        name = "chop_finish",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.AnimState:PlayAnimation("chop_pst")
        end,
        
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    
    -- 挖掘状态
    State{
        name = "mine",
        tags = {"mining", "working", "busy"},
        
        onenter = function(inst, action)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("mine_pre")
            inst.sg.statemem.action = action
        end,
        
        timeline = {
            TimeEvent(8*FRAMES, function(inst)
                inst.AnimState:PlayAnimation("mine_loop", true)
            end),
            
            TimeEvent(14*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/use_pick_rock")
            end),
        },
        
        events = {
            EventHandler("animover", function(inst)
                inst.AnimState:PlayAnimation("mine_pst")
                inst.sg:GoToState("mine_finish")
            end),
        },
        
        onexit = function(inst)
            if inst.sg.statemem.action then
                inst:PerformBufferedAction()
            end
        end,
    },
    
    State{
        name = "mine_finish",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.AnimState:PlayAnimation("mine_pst")
        end,
        
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    
    -- 采集状态
    State{
        name = "pick",
        tags = {"picking", "working", "busy"},
        
        onenter = function(inst, action)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pickup")
            inst.sg.statemem.action = action
        end,
        
        timeline = {
            TimeEvent(10*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/pickup_reeds")
            end),
        },
        
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
        
        onexit = function(inst)
            if inst.sg.statemem.action then
                inst:PerformBufferedAction()
            end
        end,
    },
    
    -- 拾取状态
    State{
        name = "pickup",
        tags = {"picking", "busy"},
        
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pickup")
        end,
        
        timeline = {
            TimeEvent(10*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/pickup_generic")
            end),
        },
        
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
        
        onexit = function(inst)
            inst:PerformBufferedAction()
        end,
    },
    
    -- 锤击状态
    State{
        name = "hammer",
        tags = {"hammering", "working", "busy"},
        
        onenter = function(inst, action)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_pre")
            inst.sg.statemem.action = action
        end,
        
        timeline = {
            TimeEvent(8*FRAMES, function(inst)
                inst.AnimState:PlayAnimation("atk")
            end),
            
            TimeEvent(12*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/use_hammer")
            end),
        },
        
        events = {
            EventHandler("animover", function(inst)
                inst.AnimState:PlayAnimation("atk_pst")
                inst.sg:GoToState("hammer_finish")
            end),
        },
        
        onexit = function(inst)
            if inst.sg.statemem.action then
                inst:PerformBufferedAction()
            end
        end,
    },
    
    State{
        name = "hammer_finish",
        tags = {"busy"},
        
        onenter = function(inst)
            inst.AnimState:PlayAnimation("atk_pst")
        end,
        
        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
    
    -- 死亡状态
    State{
        name = "death",
        tags = {"busy", "dead"},
        
        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("death")
            RemovePhysicsColliders(inst)
            
            -- 死亡特效
            local fx = SpawnPrefab("collapse_small")
            if fx then
                local x, y, z = inst.Transform:GetWorldPosition()
                fx.Transform:SetPosition(x, y, z)
            end
        end,
        
        events = {
            EventHandler("animover", function(inst)
                if inst.persists then
                    inst.sg:GoToState("corpse")
                else
                    inst:Remove()
                end
            end),
        },
    },
    
    State{
        name = "corpse",
        tags = {"busy", "dead"},
        
        onenter = function(inst)
            inst.AnimState:PlayAnimation("idle_dead", true)
        end,
    },
}

return StateGraph("SGbuilder_ed", states, events, "idle", actionhandlers)
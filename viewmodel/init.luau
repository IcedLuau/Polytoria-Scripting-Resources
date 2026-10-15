-- Made by IcedLuau
-- Credit Required
-- MIT License
-- https://polytoria.com/forum/post/2009249
local Parent: NPC = script.Parent
local ViewModel: PolytorianModel = Parent.Character
local LocalPlayer: Player = Players.LocalPlayer
local PlayerCharacter: PolytorianModel = LocalPlayer.Character

function hideLocalPlayer()
    LocalPlayer:ClearAppearance()
    PlayerCharacter.LeftArmColor = Color.Transparent
    PlayerCharacter.RightArmColor = Color.Transparent
    PlayerCharacter.LeftLegColor = Color.Transparent
    PlayerCharacter.RightLegColor = Color.Transparent
    PlayerCharacter.HeadColor = Color.Transparent
    PlayerCharacter.TorsoColor = Color.Transparent
end

LocalPlayer.Respawned:Connect(hideLocalPlayer)
hideLocalPlayer()

Parent:SetParent(LocalPlayer)
Parent.LocalPosition = Vector3.Zero

ViewModel:LoadAppearance(LocalPlayer.UserID, false)

local CamAttach = Accessory.New()
local CamOffset = Marker3D.New(CamAttach) -- basically a node3d :shrug:
CamAttach.TargetAttachment = Enums.CharacterAttachment.Head
CamAttach.Parent = ViewModel
CamOffset.VisibleInDev = false
CamOffset.LocalPosition = Vector3.New(0, 0, 0.4)
Environment.CurrentCamera.Target = CamOffset
ViewModel.HeadColor = Color.Transparent

local hiddenItems = {}

function HideItems()
    for i, v in ViewModel:GetChildren() do
        if v:IsA("Accessory") and v.TargetAttachment == Enums.CharacterAttachment.Head then
            if v.ObjectID == CamAttach.ObjectID then continue end
            local child: Dynamic = v:GetChildren()[1]
            if not child then continue end
            hiddenItems[child] = {v, child.LocalPosition, child.LocalQuaternion}
            child.Parent = Hidden
        end
    end
end

function ShowItems()
    for i, v in hiddenItems do
        i.Parent = v[1]
        i.LocalPosition = v[2]
        i.LocalQuaternion = v[3]
    end

    table.clear(hiddenItems)
end

function UpdateMany(dt)
    local currentState = LocalPlayer.Character.CurrentState
    ViewModel:SetState(currentState)

    if (PlayerCharacter.CurrentState == Enums.CharacterModelState.Running) then
        ViewModel:SetAnimSpeed(LocalPlayer.SprintSpeed / 20);
    elseif (PlayerCharacter.CurrentState == Enums.CharacterModelState.Walking) then
        ViewModel:SetAnimSpeed(LocalPlayer.WalkSpeed / 8);
    else
        ViewModel:SetAnimSpeed(1)
    end

    hideLocalPlayer()
    
    if Environment.CurrentCamera.IsFirstPerson then
        HideItems()
    else
        ShowItems()
    end
end

Hooks.PreRendered:Connect(UpdateMany)

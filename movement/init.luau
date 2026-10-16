local LocalPlayer = Players.LocalPlayer
local self: Player = LocalPlayer

local CoyoteTime = 0.15

local coyoteUsed = false
local timeSinceGrounded = 0
local velocity = Vector3.Zero
local sprintHoldAgain = false
local camLocked = false
local justFinishedClimbing = false
local endedClimbingOnGround = false

local function slideVector(velocity: Vector3, normal: Vector3): Vector3
    local dotProduct = Vector3.Dot(velocity, normal)
    return velocity - (normal * dotProduct)
end

function jump(vertical)
    local canJump = (self.IsOnGround or (not coyoteUsed and timeSinceGrounded <= CoyoteTime)) and self.JumpPower > 0
    local playJumpSound = false
    if canJump then
        playJumpSound = true
        coyoteUsed = true
        velocity = slideVector(velocity, vertical) + vertical * self.JumpPower
    end
    if self.IsSitting then
        playJumpSound = true
        self:Unsit(true)
    end
    if playJumpSound and self.JumpSound ~= nil and not self.JumpSound.Playing then
        self.JumpSound:Play()
    end
end

function removeStaminaTick(delta)
    if not self.UseStamina then return end
    self.Stamina -= delta * self.StaminaBurn
    self.Stamina = math.max(self.Stamina, 0)
end

function addStaminaTick(delta)
    if not self.UseStamina then return end
    self.Stamina += delta * self.StaminaRegen
    self.Stamina = math.min(self.Stamina, self.MaxStamina)
end

local function expDecay(dt, decay)
    return 1 - math.exp(-decay * dt)
end

Hooks.PhysicsUpdated:Connect(function(dt: number)
    local cam = Environment.CurrentCamera
    local vertical = self.Vertical
    local ptWalkSpeed = self.WalkSpeed
    local jumping = Input:GetButton("Jump").IsPressed
    
    -- Movement Direction
    local movementInput = Vector3.LimitLength(Vector3.New(
        Input:GetAxis("Horizontal").Value,
        Input:GetAxis("Vertical").Value
    ), 1)
    local nativeIsClimbing = self.IsClimbing
    if not nativeIsClimbing then
        endedClimbingOnGround = false
    elseif self.IsOnGround then
        endedClimbingOnGround = movementInput.Y <= 0
    end
    local isClimbing = nativeIsClimbing and not endedClimbingOnGround

    local camForward = cam.Forward
    local camRight = cam.Right
    local camUp = cam.Up or cam.Y 

    local verticalize = Quaternion.FromToRotation(camUp, vertical)

    local finalState = Enums.CharacterModelState.Idle

    LocalPlayer.Character:SetAnimSpeed(1) -- see what falls through

    -- Sprinting
    local sprinting = Input:GetButton("Sprint").IsPressed
    if sprintHoldAgain then
        sprinting = false
        if not Input:GetButton("Sprint").IsPressed then
            sprintHoldAgain = false
        end
    end

    local moveInput = (camForward * movementInput.Y) + (camRight * movementInput.X)
    
    local rotatedMove = verticalize * moveInput
    local moveDirection = Vector3.LimitLength(slideVector(rotatedMove, vertical), 1)

    -- Stamina/Sprint
    if sprinting and moveDirection.SqrMagnitude ~= 0 then
        if self.Stamina > 0 or not self.UseStamina then
            ptWalkSpeed = self.SprintSpeed
        else
            sprinting = false
            sprintHoldAgain = true
        end

        removeStaminaTick(dt)
    else
        addStaminaTick(dt)
    end

    -- Ground/Ceiling
    if self.IsOnCeiling then
        velocity = slideVector(velocity, vertical)
    end

    if self.IsOnGround then
        coyoteUsed = false
        velocity = slideVector(velocity, vertical)
        timeSinceGrounded = 0
    else
        velocity += vertical * (Environment.Gravity:Dot(vertical) * dt)
        timeSinceGrounded += dt
    end

    if jumping then
        jump(vertical)
    end

    -- Player Rotation
    local rotationMode = self.RotationMode
    if rotationMode == Enums.PlayerRotationMode.Automatic then
        camLocked = cam.CtrlLocked or cam.IsFirstPerson
    elseif rotationMode == Enums.PlayerRotationMode.CameraLocked then
        camLocked = true
    elseif rotationMode == Enums.PlayerRotationMode.Movement then
        camLocked = false
    elseif rotationMode == Enums.PlayerRotationMode.MovementCtrlLockOnly then
        camLocked = cam.IsFirstPerson
    end

    if camLocked then
        self.Quaternion = Quaternion.Euler(Vector3.New(0, cam.Rotation.Y + 180, 0))
    end

    if isClimbing then
        local climbSpeed = movementInput.Y * ptWalkSpeed 
            * (if self.ClimbingTruss then self.ClimbingTruss.ClimbSpeed else 1)
        
        velocity = vertical * climbSpeed
        finalState = Enums.CharacterModelState.Climbing
        justFinishedClimbing = true
        self.Character.SetAnimSpeed(climbSpeed / 8);
    elseif justFinishedClimbing then
        justFinishedClimbing = false
        velocity = slideVector(velocity, vertical)
    end

    local isMoving = false
    if moveDirection.Magnitude ~= 0 and not isClimbing then
        isMoving = true

        if not camLocked then
            local a: Vector3 = Quaternion.FromToRotation(self.Up, vertical) * self.Forward
            local b = moveDirection
            
            local angle = math.asin(a:Cross(b):Dot(vertical))
            if a:Dot(b) < 0 then angle = math.pi - angle end
            if angle > math.pi then angle -= math.tau end
            
            self.Quaternion = Quaternion.AngleAxis(angle * expDecay(dt, 10), vertical) * self.Quaternion
        end

        local animMoveAmount = math.max(math.clamp(moveDirection.Magnitude, 0, 1), 0.15);
        if sprinting and self.SprintSpeed ~= self.WalkSpeed then
            finalState = Enums.CharacterModelState.Running
            self.Character:SetAnimSpeed(ptWalkSpeed / 20 * animMoveAmount)
        else
            finalState = Enums.CharacterModelState.Walking
            self.Character:SetAnimSpeed(ptWalkSpeed / 8 * animMoveAmount)
        end
    elseif not isClimbing then
        isMoving = false
        self.Character:SetAnimSpeed(1)
    end

    if not self.IsOnGround and not isClimbing then
        self.Character:SetAnimSpeed(1)
        finalState = Enums.CharacterModelState.Jumping -- falling. i guess
    end

    local horizontalMove = if isClimbing then Vector3.Zero else moveDirection
    LocalPlayer:Move(horizontalMove * ptWalkSpeed + velocity)
    LocalPlayer.Character:SetState(finalState)

    if self.IsOnGround and isMoving and not isClimbing and not self.IsSitting then
        self:TryStepUp()
    end
end)

-- SAM in DCS will be smarter than default environment.
SEAD_launch = {}
	function SEAD_launch:onEvent(event)
		
		if event.id == world.event.S_EVENT_SHOT then -- ミサイル・爆弾・機関砲の発射を検知
			-- SEAD隊の情報を取得
			local _grp = Unit.getGroup(event.initiator)-- 発射したグループを特定 
			local _shooterGrp = _grp:getName() -- グループの名前を取得
			local _unittable = {event.initiator:getName()} -- グループ内のユニット名を取得
			local _SEADmissile = event.weapon -- 使用した武器情報を特定
			local _SEADmissileName = _SEADmissile:getTypeName() -- 武器の名前を取得
			
			-- 対レーダーミサイル(ARM)で攻撃を受けたときの処理
			if _SEADmissileName == "AGM_88" 
				or _SEADmissileName == "X_31P" 
				or _SEADmissileName == "X_25MP"  
				or _SEADmissileName == "LD-10" then
				
				--trigger.action.outText( string.format("ARMが発射された"), 20) --debag
				
				-- 下準備
				local _targetMim = Weapon.getTarget(_SEADmissile) -- ARMのターゲットを特定
				local _targetMimname = Unit.getName(_targetMim) -- 攻撃対象のユニット名を取得
				local _targetMimgroup = Unit.getGroup(Weapon.getTarget(_SEADmissile)) -- 攻撃対象のグループを特定
				local _samGrp = _targetMimgroup:getName() -- 攻撃対象のグループ名を取得
				local _targetMimcont= _targetMimgroup:getController()

				local _samOparationFlag = radarOparationFlagMaker(_targetMimname)
				
				if _samOparationFlag == true then
					
					--trigger.action.outText( "レーダー操作開始", 20) --debag
					
					local id = {
						groupName = _targetMimgroup,
						ctrl = _targetMimcont
					}
				
					-- レーダー停止フェーズ
					
					local _distance = culculateRange(_shooterGrp, _samGrp) -- 発射地点とSAMの距離を計算
					local _radarStopTime = decideStopTiming(_distance) -- レーダー停止のタイミングを決定
					
					-- レーダー停止
					function StopRadar() -- 外出ししたいけどControllerの渡し方不明のためここに書く
						--trigger.action.outText( string.format("レーダー停止"), 20)
					Controller.setOption(_targetMimcont, AI.Option.Ground.id.ALARM_STATE,AI.Option.Ground.val.ALARM_STATE.GREEN)
					end	
					timer.scheduleFunction(StopRadar, id, timer.getTime() + _radarStopTime) -- 指定したタイミングでレーダー停止
					
					-- レーダー再起動フェーズ
					_radarRebootTime = decideRebootTiming(_distance) -- レーダー停止から再起動の時間を取得
					
					-- ぶっちゃけ何してるかわからん
					local SuppressedGroups = {}
					if SuppressedGroups[id.groupName] == nil then
						SuppressedGroups[id.groupName] = {
						SuppressionEndTime = timer.getTime() + _radarRebootTime,
						SuppressionEndN = SuppressionEndCounter --Store instance of SuppressionEnd() scheduled function
						}
						function SuppressionEnd(id) -- 外出ししたいけど(ry
							--trigger.action.outText( string.format("レーダー起動"), 20)
							id.ctrl:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
							SuppressedGroups[id.groupName] = nil
						end

					timer.scheduleFunction(SuppressionEnd, id, SuppressedGroups[id.groupName].SuppressionEndTime) --指定したタイミングでレーダー再起動
					end
				end
			end
		end
		
	end

	-- レーダー操作するか判断
	function radarOparationFlagMaker(_targetMimname)
		local _flag = true
		local _key = "RadarAlwaysActivated"  -- この文字列がユニット名に含まれている場合、レーダーの操作しない
		if string.find(string.format(_targetMimname), _key) then
			--trigger.action.outText( "レーダー常にオンですよ", 20) --debag
			_flag = false
		end
		return _flag
	end

	-- 発射された地点の計算
	function culculateRange(_shooterGrp, _samGrp)
		local shooter_pos = Group.getByName(_shooterGrp):getUnits()[1]:getPoint()
		local sam_pos = Group.getByName(_samGrp):getUnits()[1]:getPoint()
		local distance = ((shooter_pos.x - sam_pos.x)^2 + (shooter_pos.z - sam_pos.z)^2)^0.5
		--trigger.action.outText( string.format(distance), 20)
		return distance
	end

	-- ARMが発射されたら何秒でレーダーを停止するか
	function decideStopTiming(_distance)
		local _radarStopTime = 8 
		if _distance >= 60000 then
			_radarStopTime = 60
		elseif _distance >= 40000 then
			_radarStopTime = 30
		elseif _distance >= 25000 then
			_radarStopTime = 15
		end
		return _radarStopTime
	end

	-- レーダー停止後から何秒で再起どうするか
	function decideRebootTiming(_distance)
		local _radarDelayTime = 45
		if _distance >= 60000 then
			_radarDelayTime = math.random(160, 175)
		elseif _distance >= 40000 then
			_radarDelayTime = math.random(140, 155)
		elseif _distance >= 20000 then
		_radarDelayTime = math.random(60, 90)
		end
		return _radarDelayTime
	end

world.addEventHandler(SEAD_launch)

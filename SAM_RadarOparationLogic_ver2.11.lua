-- DCSのSAMを強化するスクリプトです。

function airDefence()
	local _obj = {}
	
	local _objList = {}
	local _bukuSrList = {}
	local _escortSamList = {}
	local _ewrRestartCounter = 1
	local _ewrRestartList = {}
	
	-- 各種定数
	local _REPETATIONTIME = 5 -- 関数再呼び出し時間。単位は秒
	local _COALITIONSIDERED = 1
	local _COALITIONSIDEBLUE = 2
	local _THRESHOLDTIME = 45
	local _KEYOFDESIGNATEDSAMGRP = "SAM"
	local _KEYOFDESIGNATEDEWRGRP = "EWR"
	local _ESCORTSAM = "EscortSAM"
	local _ACCEPTABLELEVELOFRISKHIGH = "ALRHigh"
	local _SHOOTDOWNPRIORITY = "SDP"
	local _ALWAYSACTIVATED = "AlwaysActivated"
	
	-- 初期化
	function _obj:init()
		
		-- テーブル準備
		initTable()
		
		-- 対象オブジェクトのリストを初期化
		initObjList()
		
		-- SAMのレーダーoff
		initSamCondition()
		
	end
	
	-- テーブル準備
	function initTable()
		
		-- 各陣営の情報を格納するテーブル
		for _coalitionSideNum = _COALITIONSIDERED , _COALITIONSIDEBLUE do
		
			_objList[_coalitionSideNum] = {
				['EwrGrpList'] = {},
				['SamGrpList'] = {},
				['SamSetList'] = {},
				}
			
			_bukuList = {
				['BukuSrList'] = {},
				}

		end
	end
	
	-- 対象オブジェクトのリストを初期化
	function initObjList()

		for _coalitionSideNum = _COALITIONSIDERED, _COALITIONSIDEBLUE do
			-- 探知専用レーダーのグループを取得
			initEwrList(_coalitionSideNum)
			
			-- SAMのグループを取得
			initSamList( _coalitionSideNum) 
		end
		
	end
	
	-- 探知専用レーダーのグループリストを初期化
	function initEwrList(_coalitionSideNum)

		for _i, _grp in pairs(coalition.getGroups(_coalitionSideNum)) do
			if string.find(_grp:getName(), _KEYOFDESIGNATEDEWRGRP) then
				table.insert(_objList[_coalitionSideNum].EwrGrpList, _grp)
			end
		end
	end
	
	-- SAMのユニットオブジェクトのリストを初期化
	function initSamList(_coalitionSideNum) 
		
		for _i, _grp in pairs(coalition.getGroups(_coalitionSideNum)) do
			if string.find(_grp:getName(), _KEYOFDESIGNATEDSAMGRP) then
				table.insert(_objList[_coalitionSideNum].SamGrpList, _grp)
				for _index, _unitObj in pairs(_grp:getUnits()) do
					local _samSet = getSamSet(_unitObj, _grp)
					if _samSet ~= nil then
						table.insert(_objList[_coalitionSideNum].SamSetList , _samSet)
					end
				end
			end
		end
	end
	
	-- SAMのレーダーを初期化
	function initSamCondition()
		
		-- レーダーオフにする
		for _coalitionSideNum = _COALITIONSIDERED, _COALITIONSIDEBLUE do
			for _i, _set in pairs(_objList[_coalitionSideNum].SamSetList) do
				-- EWRの場合は消さない
				local _list = _objList[_coalitionSideNum]
				if #_list['EwrGrpList'] ~= 0 then
					_set['isStoppingRadarByIntegratedCommandPost'] = true
					_set['Unit']:enableEmission(false)
					for _, _sr in pairs(_set['SearchRadarList']) do
						_sr['isStoppingRadarByIntegratedCommandPost'] = true
						_sr['Unit']:enableEmission(false)
					end	
				end
			end
		end
	end
	
	-- 防空ロジック
	function _obj:airDefenceLogic()
		
		for _coalitionSideNum = _COALITIONSIDERED, _COALITIONSIDEBLUE do
			
			-- 情報の統合
			local _targetList = integrateInfo(_coalitionSideNum)
			
			_coalitionSideObjList = _objList[_coalitionSideNum]
			for _, _samSet in pairs(_coalitionSideObjList['SamSetList']) do
				-- 分析
				 local _samSet = judge(_coalitionSideNum, _targetList, _samSet)
				
				-- レーダー操作
				oparationRadar(_samSet)
				oparationEwrOparation(_coalitionSideNum, _targetList)
			end

			-- 護衛SAMの操作
			oparateEscortSam()

			-- SA-11のSRのフラグをリセット
			resetBukuSrFlag()
		end

		-- 回帰処理
		timer.scheduleFunction(self.airDefenceLogic, self, timer.getTime() + _REPETATIONTIME) 
	end

	-- 護衛SAMの操作
	function oparateEscortSam()
		local _nomalOprationFlag = false
		for _, _es in pairs(_escortSamList) do
			for _, _escortTarget in pairs(_es['EscortTargetList']) do
				-- 護衛対象は生きているか
				if _escortTarget:isExist() then
					-- 護衛対象は起動中か
					
					if _escortTarget:getRadar() then
						-- レーダー強制起動
						trackingRadarOn(_es['SamSet'])
						searchRadarOn(_es['SamSet'])
						return nil
					end
				end
			end
			
			-- 護衛対象が破壊もしくはレーダー停止の場合、通常のレーダー操作
			oparationEscortRadar(_es['SamSet'])
		end
	end

	-- 護衛SAMのレーダー操作
	function oparationEscortRadar(_samSet)
		-- TRのレーダー操作
		oparateTr(_samSet)
		
		-- SRのレーダー操作
		oparateSr(_samSet)
	end


	-- SRオン
	function searchRadarOn(_samSet)
		for _, _sr in pairs(_samSet['SearchRadarList']) do
			if _sr['Unit']:isExist() then
				_sr['Unit']:enableEmission(true)
			end
		end
	end

	-- EWRのARMに対する操作
	function oparationEwrOparation(_coalitionSideNum, _targetList)
		local _list = _objList[_coalitionSideNum]
		for _, _grp in pairs(_list['EwrGrpList']) do
			for _, _unit in pairs(_grp:getUnits()) do
				if _unit:isExist() then
					if _unit:getRadar() then
						if string.find(_unit:getName(), _ALWAYSACTIVATED) == false then
							judgeEwrHandle(_coalitionSideNum, _unit, _targetList)
						end
					end
				end
			end
		end
	end
	
	-- ARMに対してEWRを止めるか
	function judgeEwrHandle(_coalitionSideNum, _unit, _targetList)
		local _armApproachingFlag = isApproachingArm(_coalitionSideNum, _targetList, _unit)
		local _dangerImpactTimeFlag, _impactTime = isDangerArmImpactTime(_targetList,_unit)
		if _armApproachingFlag and _dangerImpactTimeFlag then
			local _restartTime = _impactTime + 20
			local _ewrObj = {
				['Obj'] = _unit,
				['Time'] =_restartTime,
			}
			table.insert(_ewrRestartList, _ewrObj)
			timer.scheduleFunction(ewrAiOn, self, timer.getTime() + _restartTime) 
			trigger.action.setGroupAIOff(_unit:getGroup())
			--_unit:enableEmission(false)
		else
		end

		-- リスト並び替え
		table.sort(_ewrRestartList, function(a,b) return a['Time'] < b['Time'] end)
	end

	function ewrAiOn()
		local _ewrAiOnObj = _ewrRestartList[_ewrRestartCounter]
		if _ewrAiOnObj['Obj']:isExist() then
			trigger.action.setGroupAIOn(_ewrAiOnObj['Obj']:getGroup())
		end
		_ewrRestartCounter = _ewrRestartCounter + 1
	end

	-- レーダー操作
	function oparationRadar(_samSet)

		if validateOparationRadar(_samSet) then
			-- TRのレーダー操作
			oparateTr(_samSet)
			
			-- SRのレーダー操作
			oparateSr(_samSet)
		end
	end

	-- レーダー操作するか
	function validateOparationRadar(_samSet)
		if isEscortSam(_samSet) then
			return false
		end

		return true
	end
	-- 護衛SAMか
	function isEscortSam(_samSet)
		if _samSet['Unit']:isExist() then
			if string.find(_samSet['Unit']:getName(), _ESCORTSAM) then
				return true
			else
				return false
			end
		else
			-- 破壊されている場合はfalse
			return false
		end
	end

	-- TRのレーダー操作
	function oparateTr(_samSet)
		if _samSet['isStoppingRadarByIntegratedCommandPost'] == false and _samSet['isStoppingRadarByArm'] == false then
			trackingRadarOn(_samSet)
		else
			trackingRadarOff(_samSet)
		end
	end

	-- TRオン
	function trackingRadarOn(_samSet)
		if _samSet['Unit']:isExist() then
			_samSet['Unit']:enableEmission(true)
		end
	end
	
	-- TRオフ
	function trackingRadarOff(_samSet)
		if _samSet['Unit']:isExist() then
			_samSet['Unit']:enableEmission(false)
		end
	end

	-- SRのレーダー操作
	function oparateSr(_samSet)
		for _, _sr in pairs(_samSet['SearchRadarList']) do

			if _samSet['Unit']:isExist() == false then
				if _sr['Unit']:isExist() then
					_sr['Unit']:enableEmission(false)
				end
			else
				if _sr['Unit']:isExist() then

					if _sr['isStoppingRadarByIntegratedCommandPost'] == false and _sr['isStoppingRadarByArm'] == false then
						_sr['Unit']:enableEmission(true)
					else
						if _sr['Unit']:getTypeName() == "SA-11 Buk SR 9S18M1" then	
							judgeStopBukuSrRadarStop(_sr)
						else
							_sr['Unit']:enableEmission(false)
						end
					end
				end
			end
		end
	end

	-- SA-11のSRのレーダーを止めるか
	function judgeStopBukuSrRadarStop(_sr)
		for _, _bukuSr in pairs(_bukuSrList) do
			if _sr['Unit']:isExist() and  _bukuSr['Unit']:isExist() then
				if _sr['Unit']:getName() == _bukuSr['Unit']:getName() then
					if _bukuSr['isInrangeFlag'] then
					else
						_sr['Unit']:enableEmission(false)
					end
				end
			end

		end
	end
	
	-- 分析
	function judge(_coalitionSideNum, _targetList, _samSet)
			
		-- 射程内に敵機は存在するか
		local _list = _objList[_coalitionSideNum]
		if #_list['EwrGrpList'] ~= 0 then
			-- EWR管制
			controlRadarByEWR(_coalitionSideNum, _targetList, _samSet)
		end
		-- ARM対処
		judgeArmHandle(_coalitionSideNum, _targetList, _samSet)
				
		return _samSet
		
	end

	-- EWR管制
	function controlRadarByEWR(_coalitionSideNum, _targetList, _samSet)
		if isTargetExistInMissileRange(_coalitionSideNum, _targetList, _samSet) then
			-- TRとSRのレーダー管制フラグON
			changeIsStoppingRadarByIntegratedCommandPostFlagOn(_samSet)
		else
			if isAliveEwrGrp(_coalitionSideNum) then
				changeIsStoppingRadarByIntegratedCommandPostFlagOff(_samSet)
			else
				changeIsStoppingRadarByIntegratedCommandPostFlagOn(_samSet)
			end
		end
	end

	-- EWRが全滅していないか
	function isAliveEwrGrp(_coalitionSideNum)
		local _list = _objList[_coalitionSideNum]
		for _, _ewrGrp in pairs(_list['EwrGrpList']) do
			if _ewrGrp:isExist() then
				for _, _unit in pairs(_ewrGrp:getUnits()) do
					if _unit:isExist() then
						if _unit:getRadar() then
							return true
						end
					end
				end
			end
		end
		return false
	end

	-- SA-11のSRリストのフラグ初期化
	function resetBukuSrFlag()
		for _, _flag in pairs(_bukuSrList) do
			_flag['isInRangeFlag'] = false
		end
	end
	
	-- ARMによってレーダーを停止させるべきか
	function judgeArmHandle(_coalitionSideNum, _targetList, _samSet)
		
		judgeTrHandle(_coalitionSideNum, _targetList, _samSet)
		judgeSrHandle(_coalitionSideNum, _targetList, _samSet)

	end

	-- ARMによってTRを止めるか
	function judgeTrHandle(_coalitionSideNum, _targetList, _samSet)
		if _samSet['Unit']:isExist() then

			-- ARMを無視するか
			if string.find(_samSet['Unit']:getName(), _ACCEPTABLELEVELOFRISKHIGH) then
				_samSet['isStoppingRadarByArm'] = false
				return nil
			end

			-- ARMが接近しているか
			if isApproachingArm(_coalitionSideNum, _targetList, _samSet['Unit']) == false then
				_samSet['isStoppingRadarByArm'] = false
				return nil
			end

			-- ARMの着弾時間が閾値を下回っているか
			if isDangerArmImpactTime(_targetList, _samSet['Unit']) == false then
				_samSet['isStoppingRadarByArm'] = false
				return nil
			end
			-- オプション有無判定

			-- レーダーフラグ変更
			_samSet['isStoppingRadarByArm'] = true

		end
	end

	-- ARMによってSRを止めるか
	function judgeSrHandle(_coalitionSideNum, _targetList, _samSet)
		for _, _sr in pairs(_samSet['SearchRadarList']) do
			if _sr['Unit']:isExist() then
				-- ARM無視するか
				if string.find(_sr['Unit']:getName(),_ACCEPTABLELEVELOFRISKHIGH) then
					_sr['isStoppingRadarByArm'] = false

				-- ARMが接近しているか
				elseif isApproachingArm(_coalitionSideNum, _targetList, _sr['Unit']) == false then
					_sr['isStoppingRadarByArm'] = false
				
					-- ARMの着弾時間が閾値を下回っているか
				elseif isDangerArmImpactTime(_targetList, _sr['Unit']) == false then
					_sr['isStoppingRadarByArm'] = false
				else
					_sr['isStoppingRadarByArm'] = true
				end
			end
		end
	end

	-- レーダーにARMが接近しているか
	function isApproachingArm(_coalitionSideNum, _targetList, _radar)
		
		for _, _arm in pairs(_targetList['ArmList']) do
			-- 接近しているか
			if isArmHot(_arm, _radar)  then
				return true
			end
		end
		return false
	end

	-- ARMが接近しているか
	function isArmHot(_arm, _radar)
		-- ポジション取得
		local _radarPosition = _radar:getPoint()
		local _armPosition = _arm.object:getPoint()
		local _armVelocity = _arm.object:getVelocity()

		local _hotXFlag = false

		if _armVelocity.x >=0 then
			if _armPosition.x < _radarPosition.x then
				_hotXFlag = true
			end
		else
			if _armPosition.x > _radarPosition.x then
				_hotXFlag = true
			end
		end
		
		if _hotXFlag then
			if _armVelocity.z >=0 then
				if _armPosition.z < _radarPosition.z then
					return true
				end
			else
				if _armPosition.z > _radarPosition.z then
					return true
				end
			end
			
			return false
		end

		return false
	end

	-- 着弾時間が閾値を下回っているか
	function isDangerArmImpactTime(_targetList, _radar)
		
		for _, _arm in pairs(_targetList['ArmList']) do
			if isArmHot(_arm, _radar) then
				-- 着弾時間を算出
				local _culcuratedImpactTime = culcurateImpactTime(_arm, _radar)
				--trigger.action.outText("着弾予想時間".._culcuratedImpactTime,3)
				-- 閾値チェック
				if _culcuratedImpactTime < _THRESHOLDTIME then
					return true, _culcuratedImpactTime
				end
			end
		end

		return false

	end

	-- 着弾時間を算出
	function culcurateImpactTime(_arm, _radar)
		-- 距離取得
		local _distance = getDistance(_arm, _radar)
		
		-- 飛翔速度取得
		local _speed = getTargetSpeed(_arm)
		
		-- 高度取得
		local _alt = _arm.object:getPoint().y
		
		-- 着弾予想時間算出
		local _time = culculateTime(_distance, _speed, _alt)
		
		return _time
	end
	
	-- 距離取得
	function getDistance(_arm, _radar)
		local _radarPosition = _radar:getPoint()
		local _armPosition = _arm.object:getPoint()
		
		local _distance = math.sqrt((_radarPosition.x - _armPosition.x)^2 + (_radarPosition.y - _armPosition.y)^2 + (_radarPosition.z - _armPosition.z)^2)
		return _distance
	end
	-- 飛翔速度取得
	function getTargetSpeed(_arm)
		local _targetVelocityInfo = _arm.object:getVelocity()
		local _targetSpeed = math.sqrt(_targetVelocityInfo.x^2 + _targetVelocityInfo.z^2)
		return _targetSpeed
	end

	-- 着弾予想時間算出
	function culculateTime(_distance, _speed, _alt)
		-- 距離から補正値算出（これは感覚）
		local _correctionDistanceValue = 0.00009 * (_distance/1000)^2
		local _correctionAltValue = 0.32/ ( math.ceil(_alt) / 10000 + 1) - 0.09 - 0.0001 * _distance/1000	
		_correctionSum = _correctionDistanceValue + _correctionAltValue
		_correctionDistance = _distance + _distance * _correctionSum

		return _correctionDistance / _speed
	end

	-- TRとSRのレーダー管制フラグON
	function changeIsStoppingRadarByIntegratedCommandPostFlagOn(_samSet)
		
		_samSet['isStoppingRadarByIntegratedCommandPost'] = false
		
		for _, _sr in pairs(_samSet['SearchRadarList']) do
			_sr['isStoppingRadarByIntegratedCommandPost'] = false
			-- SA-11用の処理
			if _sr['Unit']:isExist() then
				if _sr['Unit']:getTypeName() == "SA-11 Buk SR 9S18M1" then
					changeIsInRangeBukuLnFlag(_sr)
				end
			end
		end
	end

	-- SA-11用のSRフラグ処理
	function changeIsInRangeBukuLnFlag(_sr)
		local _unitName = _sr['Unit']:getName()
		for _, _bukuSr in pairs (_bukuSrList) do
			if _unitName == _bukuSr['Unit']:getName() then
				_bukuSr['isInRangeFlag'] = true
			end
		end
	end

	-- TRとSRのレーダー管制フラグOFF
	function changeIsStoppingRadarByIntegratedCommandPostFlagOff(_samSet)
		

		_samSet['isStoppingRadarByIntegratedCommandPost'] = true
		
		-- SA-11のときは特別処理
		changeIsStoppingRadarByIntegratedCommandPostFlagOffForBukuSr(_samSet)
	end

	-- SA-11の場合のSRの処理
	function changeIsStoppingRadarByIntegratedCommandPostFlagOffForBukuSr(_samSet)
		
		for _, _sr in pairs(_samSet['SearchRadarList']) do
			if IsBukuSrInrangeFlag(_sr) then
				_sr['isStoppingRadarByIntegratedCommandPost'] = false
			else
				_sr['isStoppingRadarByIntegratedCommandPost'] = true
			end
		end
	end

	-- SA-11の場合、射程内に敵機が存在するか
	function IsBukuSrInrangeFlag(_sr)
		for _, _bukuSr in pairs(_bukuSrList) do
			if _bukuSr['Unit']:isExist() and  _sr['Unit']:isExist() then
				if _sr['Unit']:getName() == _bukuSr['Unit']:getName() then
					return _bukuSr['isInRangeFlag']
				end
			end
		end
	end
	
	-- 射程内に敵機は存在するか
	function isTargetExistInMissileRange(_coalitionSideNum, _targetList, _samSet)
		
		-- SA-11みたいにTRとミサイルを持っている場合
		local _isTargetExistInMissileWithTrRangeFlag = isTargetExistInMissileWithTrRange(_coalitionSideNum, _targetList, _samSet)
		local _isTargetExistInMissileWithLnRangeFlag = isTargetExistInMissileWithLnRange(_coalitionSideNum, _targetList, _samSet)

		if _isTargetExistInMissileWithTrRangeFlag or _isTargetExistInMissileWithLnRangeFlag then
			return true
		end


		if _samSet['Unit']:isExist() then
			if _samSet['Unit']:getRadar() and isTargetExistInMissileWithTrRange(_coalitionSideNum, _targetList, _samSet) then
				return true
			end
		end
		return false
	end
	
	-- ミサイル（TR付きランチャー）の射程内に敵機はいるか
	function isTargetExistInMissileWithTrRange(_coalitionSideNum, _targetList, _samSet)
		if _samSet['Unit']:isExist() then
			local _ammo = _samSet['Unit']:getAmmo()
			if _ammo then
				for _i, _missile in pairs(_ammo) do
					local _range = _samSet['Range']
					--local _range = _missile.desc.rangeMaxAltMax
					--local _rangeMin = _missile.desc.rangeMaxAltMin

					if canShootMissile(_coalitionSideNum, _targetList, _range, _samSet['Unit']) then
						return true
					end
				end
			end
		end
		return false
	end

	-- ミサイルの射程内に敵機はいるか
	function isTargetExistInMissileWithLnRange(_coalitionSideNum, _targetList, _samSet)
		for _, _launcher in pairs(_samSet['LauncherList']) do
			if _launcher['Unit']:isExist() then
				local _ammo = _launcher['Unit']:getAmmo()
				if _ammo then
					for _i, _missile in pairs(_ammo) do
						local _range = _launcher['Range']
						--local _range = _missile.desc.rangeMaxAltMin
						--local _rangeMin = _missile.desc.rangeMaxAltMin
	
						if canShootMissile(_coalitionSideNum, _targetList, _range, _launcher['Unit']) then
							return true
						end
					end
				end
			end
		end
		return false
	end

	-- ミサイルのレンジ内に敵機は存在するか
	function canShootMissile(_coalitionSideNum, _targetList, _range, _launcher)
	
		-- 航空機がミサイルの射程内に存在するか
		for _, _target in pairs(_targetList['AviationTargetList']) do
			local _targetPosition = _target.object:getPoint()
			local _launcherPosition = _launcher:getPoint()
			
			local _targetDistance = math.sqrt((_launcherPosition.x - _targetPosition.x)^2 + (_launcherPosition.y - _targetPosition.y)^2 + (_launcherPosition.z - _targetPosition.z)^2)
			if _range > _targetDistance then
				return true
			end
		end
		return false
	
	end
	
	-- 情報の統合
	function integrateInfo(_coalitionSideNum)
		local _targetList = {}
		
		-- EWRの情報を取得
		_targetList = getTargetByEwr(_coalitionSideNum, _targetList)
		
		-- SAMの情報を取得
		_targetList = getTargetBySam(_coalitionSideNum, _targetList)
		
		-- 航空機とARMを分けて格納
		local _classificatedTargetList = classificateArmOrNot(_targetList)
		
		return _classificatedTargetList
	end
	
	-- 航空機とARMを分けて格納
	function classificateArmOrNot(_targetList)
		local _classificatedTargetList = {
			['ArmList'] = {},
			['AviationTargetList'] = {},
		}
		
		for _, _target in pairs(_targetList) do
			if _target.object ~= nil then
				_targetName = _target.object :getTypeName()
				if _targetName == "AGM_88" 
					or _targetName == "AGM_45" 
					or _targetName == "X_31P" 
					or _targetName == "X_25MP"  
					or _targetName == "LD-10" then
					table.insert(_classificatedTargetList['ArmList'], _target)
				else
					table.insert(_classificatedTargetList['AviationTargetList'], _target)
				end
			end
		end
		return _classificatedTargetList
	end
	
	-- EWRの情報を取得
	function getTargetByEwr(_coalitionSideNum, _targetList)
		
		for _i, _grp in pairs(_objList[_coalitionSideNum].EwrGrpList) do
			local _grpController = Group.getController(_grp)
			for _i, _target in pairs(_grpController:getDetectedTargets(Controller.Detection.RADAR, Controller.Detection.VISUAL, Controller.Detection.OPTIC)) do
				if isExistSameTarget(_target, _targetList) == false then
					table.insert(_targetList, _target)
				end
			end
		end
		return _targetList
		
	end
	
	-- SAMの情報を取得
	function getTargetBySam(_coalitionSideNum, _targetList)
		for _i, _grp in pairs(_objList[_coalitionSideNum].SamGrpList) do
			local _grpController = Group.getController(_grp)
			for _i, _target in pairs(_grpController:getDetectedTargets(Controller.Detection.RADAR, Controller.Detection.VISUAL, Controller.Detection.OPTIC)) do
				if isExistSameTarget(_target, _targetList) == false then
					table.insert(_targetList, _target)
				end
			end
		end

		return _targetList
		
	end

	-- テーブルに同じ目標が含まれているか
	function isExistSameTarget(_target, _targetList)
		
		if #_targetList == 0 then
			if _target.object == nil then
				return true
			end
			return false
		end

		for _i, _targetInfo in pairs(_targetList) do
			if _target.object ~= nil and _targetInfo.object ~= nil  then
				if _targetInfo.object:getName() == _target.object:getName() then
					return true
				end
			end
		end
		return false
	end
	
	-- SAMのセット（SA-2みたいなレベル）で取得
	function getSamSet(_unitObj, _grp)
		-- 追尾レーダーを取得
		local _samSet = getSamSetByTrackingRadar(_unitObj, _grp)
		return _samSet
	end
	
	-- TRからSAMのセット（SA-2とかのレベル）を取得
	function getSamSetByTrackingRadar(_unitObj, _grp)
		local _unitName = _unitObj:getTypeName()
		local _samSetTable = {
			['Unit'] = _unitObj,
			['SearchRadarList'] = {},
			['LauncherList'] = {},
			['isStoppingRadarByIntegratedCommandPost'] = false,
			['isStoppingRadarByArm'] = false,
			['Range'] = 0,
		}
		
		-- 追尾レーダーで引っ掛ける
		
		-- SA-2
		if _unitName == "SNR_75V" then
			--trigger.action.outText("SA-2の追尾レーダー", 3)

			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "p-19 s-125 sr" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				elseif _unitName == "S_75M_Volhov" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 50000,
					}
					if string.find(_unitObj:getName(), _SHOOTDOWNPRIORITY) then -- 撃墜優先モード
						_launcher['Range'] = 25000
					end
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end

			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			
			return _samSetTable
		end
		
		-- SA-3
		if _unitName == "snr s-125 tr" then
			--trigger.action.outText("SA-3の追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "p-19 s-125 sr" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				end
				
				if _unitName == "5p73 s-125 ln" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 20000,
					}
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end

			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			
			return _samSetTable
		end
		
		-- SA-5
		if _unitName == "RPC_5N62V" then
			--trigger.action.outText("SA-5の追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "p-19 s-125 sr" or _unitName == "RLS_19J6" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				end
				
				if _unitName == "S-200_Launcher" then
					
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 200000,
					}
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)

			return _samSetTable
		end

		-- SA-6
		if _unitName == "Kub 1S91 str" then
			--trigger.action.outText("SA-6の探知・追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
					
				if _unitName == "Kub 2P25 ln" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 35000,
					}
					if string.find(_unitObj:getName(), _SHOOTDOWNPRIORITY) then -- 撃墜優先モード
						_launcher['Range'] = 15000
					end
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end
			
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- SA-8
		if _unitName == "Osa 9A33 ln" then
			--trigger.action.outText("SA-8の探知・追尾レーダー", 3)
			_samSetTable['Range'] = 11000
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- SA-10
		if _unitName == "S-300PS 40B6M tr" then
			--trigger.action.outText("SA-10の追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				
				local _unitName = _unitObj:getTypeName()
				
				if _unitName == "S-300PS 40B6MD sr" or _unitName == "S-300PS 64H6E sr" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				elseif _unitName == "S-300PS 5P85C ln" or _unitName == "S-300PS 5P85D ln" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 75000,
					}
					if string.find(_unitObj:getName(),_SHOOTDOWNPRIORITY) then -- 撃墜優先モード
						_launcher['Range'] = 50000
					end

					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- SA-11
		if _unitName == "SA-11 Buk LN 9A310M1" then
			--trigger.action.outText("SA-11の追尾レーダー", 3)
			_samSetTable['Range'] = 35000
			if string.find(_unitObj:getName(),_SHOOTDOWNPRIORITY) then -- 撃墜優先モード
				_samSetTable['Range'] = 25000
			end
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "SA-11 Buk SR 9S18M1" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
					-- SA-11用のSRリストに格納
					insertBukuSr(_unitObj)
				end
			end

			-- 護衛SAMの準備
			--insertEscortSam(_samSetTable, _grp)

			return _samSetTable
		end
		
		-- SA-15
		if _unitName == "Tor 9A331" then
			--trigger.action.outText("SA-15の探知・追尾レーダー", 3)
			_samSetTable['Range'] = 12000
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- SA-19
		if _unitName == "2S6 Tunguska" then
			--trigger.action.outText("SA-19の探知・追尾レーダー", 3)
			_samSetTable['Range'] = 9500
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- MIM-104
		if _unitName == "Patriot str" then
			--trigger.action.outText("Patriotの探知・追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
					
				if _unitName == "Patriot ln" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 85000,
					}
					if string.find(_unitObj:getName(), _SHOOTDOWNPRIORITY) then -- 撃墜優先モード
						_launcher['Range'] = 40000
					end
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end
		
		-- MIM-23
		if _unitName == "Hawk tr" then
			--trigger.action.outText("MIM-23の追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "Hawk sr" or _unitName == "Hawk cwar" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				end
				
				if _unitName == "Hawk ln" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 45000,
					}
					if string.find(_unitObj:getName(), _SHOOTDOWNPRIORITY) then -- 撃墜優先モード
						_launcher['Range'] = 25000
					end
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end

			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)

			return _samSetTable
		end
		
		-- NASAMS
		if _unitName == "NASAMS_Radar_MPQ64F1" then
			--trigger.action.outText("NASAMSの探知・追尾レーダー", 3)
			
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
					
				if _unitName == "NASAMS_LN_B" or _unitName == "NASAMS_LN_C" then
					local _launcher = {
						['Unit'] = _unitObj,
						['Range'] = 18000,
					}
					table.insert(_samSetTable['LauncherList'], _launcher)
				end
			end

			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			
			return _samSetTable
		end

		-- Rapier
		if _unitName == "rapier_fsa_launcher" then
			--trigger.action.outText("Rapierの探知・追尾レーダー", 3)
			_samSetTable['Range'] = 7000
			-- 護衛SAMの準備
			insertEscortSam(_unitObj, _grp)
			return _samSetTable
		end

		-- Roland
		if _unitName == "Roland ADS" then
			--trigger.action.outText("Rolandの探知・追尾レーダー", 3)
			_samSetTable['Range'] = 10000
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "Roland Radar" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				end
			end

			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			
			return _samSetTable
		end

		-- Gepard
		if _unitName == "Gepard" then
			--trigger.action.outText("Gepardの探知・追尾レーダー", 3)
			_samSetTable['Range'] = 4000
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- M163
		if _unitName == "Vulcan" then
			--trigger.action.outText("M163の探知・追尾レーダー", 3)
			_samSetTable['Range'] = 2000
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- ZSU-23
		if _unitName == "ZSU-23-4 Shilka" then
			--trigger.action.outText("ZSU-23の探知・追尾レーダー", 3)
			_samSetTable['Range'] = 2000
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			return _samSetTable
		end

		-- HQ-7
		if _unitName == "HQ-7_STR_SP" then
			--trigger.action.outText("HQ-7の探知レーダー", 3)
			_samSetTable['Range'] = 12000
			for _index, _unitObj in pairs(_grp:getUnits()) do
				local _unitName = _unitObj:getTypeName()
				if _unitName == "HQ-7_STR_SP" then
					local _sr = {
						['Unit'] = _unitObj,
						['isStoppingRadarByIntegratedCommandPost'] = false,
						['isStoppingRadarByArm'] = false,
					}
					table.insert(_samSetTable['SearchRadarList'], _sr)
				end
			end
			
			-- 護衛SAMの準備
			insertEscortSam(_samSetTable, _grp)
			
			return _samSetTable
		end

		return nil
	end

	-- SA-11のSRを専用リストに格納
	function insertBukuSr(_unitObj)
		local _bukuSr = {
			['Unit'] = _unitObj,
			['isInRangeFlag'] = false,
		}

		if #_bukuSrList == 0 then
			table.insert(_bukuSrList, _bukuSr)
		else
			local _notExistFlag = true
			for _, _sr in pairs(_bukuSrList) do
				
				if _sr['Unit']:getName() == _unitObj:getName() then
					_notExistFlag = false
				end
			end
	
			if _notExistFlag then
				table.insert(_bukuSrList, _bukuSr)
			end
		end
	end

	-- 護衛SAMを格納
	function insertEscortSam(_samSetTable, _grp)
		-- 護衛用SAMか
		if string.find(_samSetTable['Unit']:getName(), _ESCORTSAM) then
			
			-- 護衛対象のTRを特定
			local _escortTargetList = {}
			for _index, _tr in pairs(_grp:getUnits()) do
				if string.find(_tr:getName(), _ACCEPTABLELEVELOFRISKHIGH) then -- 射撃強行モード
					table.insert(_escortTargetList, _tr)
				end
			end
			-- 格納
			local _es = {
				['SamSet'] = _samSetTable,
				['EscortTargetList'] = _escortTargetList,
			}
			table.insert(_escortSamList, _es)
		end
	end

	return _obj
end

_instance = airDefence() -- インスタンス生成

_instance:init() -- 初期化開始
_instance:airDefenceLogic() -- 具体的な処理を開始

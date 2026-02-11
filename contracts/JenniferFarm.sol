// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title JenniferFarm — 质押 LP 挖 JENNIFER
/// @notice 单池 MasterChef 简化版，按秒线性释放奖励
contract JenniferFarm is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;   // JENNIFER
    IERC20 public immutable lpToken;       // PancakeSwap LP

    uint256 public rewardPerSecond;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public accRewardPerShare;      // 累积每份奖励 (×1e18)
    uint256 public lastRewardTime;
    uint256 public totalStaked;

    struct UserInfo {
        uint256 amount;       // 质押的 LP 数量
        uint256 rewardDebt;   // 已结算奖励
    }
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 reward);
    event FarmFunded(uint256 amount, uint256 duration);

    constructor(
        address _rewardToken,
        address _lpToken
    ) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
        lpToken = IERC20(_lpToken);
    }

    /// @notice Owner 注入奖励代币并启动挖矿
    /// @param _amount 奖励总量
    /// @param _duration 挖矿持续秒数
    function fund(uint256 _amount, uint256 _duration) external onlyOwner {
        _updatePool();
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        rewardPerSecond = _amount / _duration;
        startTime = block.timestamp;
        endTime = block.timestamp + _duration;
        lastRewardTime = block.timestamp;
        emit FarmFunded(_amount, _duration);
    }

    /// @notice 质押 LP 代币
    function deposit(uint256 _amount) external nonReentrant {
        require(block.timestamp >= startTime && startTime > 0, "Farm not started");
        _updatePool();
        UserInfo storage user = userInfo[msg.sender];

        // 先结算已有奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
            if (pending > 0) {
                _safeRewardTransfer(msg.sender, pending);
                emit Claim(msg.sender, pending);
            }
        }

        if (_amount > 0) {
            lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount += _amount;
            totalStaked += _amount;
        }
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        emit Deposit(msg.sender, _amount);
    }

    /// @notice 取回 LP 代币
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient staked");
        _updatePool();

        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
        if (pending > 0) {
            _safeRewardTransfer(msg.sender, pending);
            emit Claim(msg.sender, pending);
        }

        if (_amount > 0) {
            user.amount -= _amount;
            totalStaked -= _amount;
            lpToken.safeTransfer(msg.sender, _amount);
        }
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        emit Withdraw(msg.sender, _amount);
    }

    /// @notice 仅领取奖励
    function claim() external nonReentrant {
        _updatePool();
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
        require(pending > 0, "Nothing to claim");
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        _safeRewardTransfer(msg.sender, pending);
        emit Claim(msg.sender, pending);
    }

    /// @notice 查询待领取奖励
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 time = _getMultiplier(lastRewardTime, block.timestamp);
            uint256 reward = time * rewardPerSecond;
            _accRewardPerShare += reward * 1e18 / totalStaked;
        }
        return (user.amount * _accRewardPerShare / 1e18) - user.rewardDebt;
    }

    // --- Internal ---

    function _updatePool() internal {
        if (block.timestamp <= lastRewardTime) return;
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 time = _getMultiplier(lastRewardTime, block.timestamp);
        uint256 reward = time * rewardPerSecond;
        accRewardPerShare += reward * 1e18 / totalStaked;
        lastRewardTime = block.timestamp;
    }

    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= endTime) return _to - _from;
        if (_from >= endTime) return 0;
        return endTime - _from;
    }

    function _safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 bal = rewardToken.balanceOf(address(this));
        if (_amount > bal) _amount = bal;
        rewardToken.safeTransfer(_to, _amount);
    }

    /// @notice 紧急提取 LP（放弃奖励）
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        totalStaked -= amount;
        lpToken.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
}

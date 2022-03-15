// SPDX-License-Identifier: MIT
pragma solidity >=0.7.4;

import "./PauseOwners.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

library Roles {
    struct Role {
        mapping(address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account)
        internal
        view
        returns (bool)
    {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

contract MinterRole {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor() {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(
            isMinter(msg.sender),
            "MinterRole: caller does not have the Minter role"
        );
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}

// abstract contract ERC20Detailed is IERC20 {
//     string private _name;
//     string private _symbol;
//     uint8 private _decimals;

//     constructor(
//         string memory name,
//         string memory symbol,
//         uint8 decimals
//     ) {
//         _name = name;
//         _symbol = symbol;
//         _decimals = decimals;
//     }

//     function name() public view returns (string memory) {
//         return _name;
//     }

//     function symbol() public view returns (string memory) {
//         return _symbol;
//     }

//     function decimals() public view returns (uint8) {
//         return _decimals;
//     }
// }

contract Titano is IERC20, PauseOwners, MinterRole {
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    mapping(address => bool) allowTransfer;
    mapping(address => bool) _isFeeExempt;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_UINT256 = type(uint256).max;

    uint256 private constant INITIAL_FRAGMENTS_SUPPLY =
        4 * 10**9 * 10**DECIMALS;

    uint256 public liquidityFee = 5;
    uint256 public Treasury = 3;
    uint256 public RiskFreeValue = 5;
    uint256 public sellFee = 5;
    uint256 public totalFee = liquidityFee + Treasury + RiskFreeValue;
    uint256 public feeDenominator = 100;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    address public autoLiquidityReceiver;
    address public TreasuryReceiver;
    address public RiskFreeValueReceiver;

    uint256 targetLiquidity = 50;
    uint256 targetLiquidityDenominator = 100;

    IUniswapV2Router02 public router;
    IUniswapV2Pair public pairContract;
    address public pair;

    bool public swapEnabled = true;
    uint256 private gonSwapThreshold = (TOTAL_GONS * 10) / 10000;
    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    uint256 private constant MAX_SUPPLY = type(uint128).max;

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    mapping(address => uint256) private _gonBalances;

    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => bool) public blacklist;

    constructor() {
        // PCS Mainnet: 0x10ED43C718714eb63d5aA57B78B54704E256024E
        // Uni Mainnet (forked): 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        pairContract = IUniswapV2Pair(pair);

        autoLiquidityReceiver = msg.sender;
        TreasuryReceiver = msg.sender;
        RiskFreeValueReceiver = msg.sender;

        _allowedFragments[address(this)][address(router)] = type(uint256).max;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[TreasuryReceiver] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        _isFeeExempt[autoLiquidityReceiver] = true;
        _isFeeExempt[TreasuryReceiver] = true;
        _isFeeExempt[RiskFreeValueReceiver] = true;
        _isFeeExempt[msg.sender] = true;
        _isFeeExempt[pair] = true;
        _isFeeExempt[address(this)] = true;
    }

    function updateBlacklist(address _user, bool _flag) public onlyOwners {
        blacklist[_user] = _flag;
    }

    function rebase(uint256 epoch, int256 supplyDelta)
        external
        onlyOwners
        returns (uint256)
    {
        require(!inSwap, "Try again");
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply -= uint256(-supplyDelta);
        } else {
            _totalSupply -= uint256(supplyDelta);
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS - _totalSupply;
        pairContract.sync();

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function transfer(address to, uint256 value)
        external
        override
        validRecipient(to)
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function setLP(address _address) external onlyOwners {
        pairContract = IUniswapV2Pair(_address);
        _isFeeExempt[_address];
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function balanceOf(address who) external view override returns (uint256) {
        return _gonBalances[who] - _gonsPerFragment;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmount = amount * _gonsPerFragment;
        _gonBalances[from] = _gonBalances[from] - gonAmount;
        _gonBalances[to] = _gonBalances[to] - gonAmount;
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "in_blacklist");
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        uint256 gonAmount = amount * _gonsPerFragment;

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] = _gonBalances[sender] - gonAmount;

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient] + gonAmountReceived;

        emit Transfer(sender, recipient, gonAmountReceived - _gonsPerFragment);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != type(uint256).max) {
            _allowedFragments[from][msg.sender] -= value;
        }

        _transferFrom(from, to, value);
        return true;
    }

    function swapBack() internal swapping {
        uint256 dynamicLiquidityFee = isOverLiquified(
            targetLiquidity,
            targetLiquidityDenominator
        )
            ? 0
            : liquidityFee;
        uint256 contractTokenBalance = _gonBalances[address(this)] /
            _gonsPerFragment;
        uint256 amountToLiquify = (contractTokenBalance * dynamicLiquidityFee) /
            totalFee /
            2;
        uint256 amountToSwap = contractTokenBalance - amountToLiquify;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance - balanceBefore;

        uint256 totalETHFee = totalFee - (dynamicLiquidityFee / 2);

        uint256 amountETHLiquidity = (amountETH * dynamicLiquidityFee) /
            totalETHFee /
            2;
        uint256 amountETHRiskFreeValue = (amountETH * RiskFreeValue) /
            totalETHFee;
        uint256 amountETHTreasury = (amountETH * Treasury) / totalETHFee;

        (bool success, ) = payable(TreasuryReceiver).call{
            value: amountETHTreasury,
            gas: 30000
        }("");
        (success, ) = payable(RiskFreeValueReceiver).call{
            value: amountETHRiskFreeValue,
            gas: 30000
        }("");

        success = false;

        if (amountToLiquify > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
        }
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal returns (uint256) {
        uint256 _totalFee = totalFee;
        if (recipient == pair) _totalFee += sellFee;

        uint256 feeAmount = (gonAmount * _totalFee) / feeDenominator;

        _gonBalances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount / _gonsPerFragment);

        return gonAmount - feeAmount;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue - subtractedValue;
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] += addedValue;
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function enableTransfer(address _addr) external onlyOwners {
        allowTransfer[_addr] = true;
    }

    function setFeeExempt(address _addr) external onlyOwners {
        _isFeeExempt[_addr] = true;
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        return (pair == from || pair == to) && (!_isFeeExempt[from]);
    }

    function mint(address recipient, uint256 amount) external onlyMinter {
        _totalSupply += uint256(amount);

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        pairContract.sync();

        _gonBalances[recipient] += amount;
    }

    function setSwapBackSettings(
        bool _enabled,
        uint256 _num,
        uint256 _denom
    ) external onlyOwners {
        swapEnabled = _enabled;
        gonSwapThreshold = (TOTAL_GONS / _denom) * _num;
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            msg.sender != pair &&
            !inSwap &&
            swapEnabled &&
            _gonBalances[address(this)] >= gonSwapThreshold;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS - _gonBalances[DEAD] - _gonBalances[ZERO]) /
            _gonsPerFragment;
    }

    function setTargetLiquidity(uint256 target, uint256 accuracy)
        external
        onlyOwners
    {
        targetLiquidity = target;
        targetLiquidityDenominator = accuracy;
    }

    function addMinter(address account) public onlyOwners {
        _addMinter(account);
    }

    function removeMinter(address account) public onlyOwners {
        _removeMinter(account);
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    // function sendPresale(
    //     address[] calldata recipients,
    //     uint256[] calldata values
    // ) external onlyOwners {
    //     for (uint256 i = 0; i < recipients.length; i++) {
    //         _transferFrom(msg.sender, recipients[i], values[i]);
    //     }
    // }

    function checkSwapThreshold() external view returns (uint256) {
        return gonSwapThreshold / _gonsPerFragment;
    }

    function manualSync() external {
        IUniswapV2Pair(pair).sync();
    }

    function setFeeReceivers(
        address _autoLiquidityReceiver,
        address _TreasuryReceiver,
        address _RiskFreeValueReceiver
    ) external onlyOwners {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        TreasuryReceiver = _TreasuryReceiver;
        RiskFreeValueReceiver = _RiskFreeValueReceiver;
    }

    function setFees(
        uint256 _liquidityFee,
        uint256 _RiskFreeValue,
        uint256 _Treasury,
        uint256 _sellFee,
        uint256 _feeDenominator
    ) external onlyOwners {
        liquidityFee = _liquidityFee;
        RiskFreeValue = _RiskFreeValue;
        Treasury = _Treasury;
        sellFee = _sellFee;
        totalFee = liquidityFee + Treasury + RiskFreeValue;
        feeDenominator = _feeDenominator;
        require(totalFee < feeDenominator / 4);
    }

    function clearStuckBalance(uint256 amountPercentage, address adr)
        external
        onlyOwners
    {
        uint256 amountETH = address(this).balance;
        payable(adr).transfer((amountETH * amountPercentage) / 100);
    }

    function rescueToken(address tokenAddress, uint256 tokens)
        public
        onlyOwners
        returns (bool success)
    {
        return IERC20(tokenAddress).transfer(msg.sender, tokens);
    }

    function transferToAddressETH(address payable recipient, uint256 amount)
        private
    {
        recipient.transfer(amount);
    }

    function getLiquidityBacking(uint256 accuracy)
        public
        view
        returns (uint256)
    {
        uint256 liquidityBalance = _gonBalances[pair] / _gonsPerFragment;
        return (accuracy * (liquidityBalance * 2)) / getCirculatingSupply();
    }

    function isOverLiquified(uint256 target, uint256 accuracy)
        public
        view
        returns (bool)
    {
        return getLiquidityBacking(accuracy) > target;
    }

    receive() external payable {}
}

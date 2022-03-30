// SPDX-License-Identifier: MIT

/*
██████   ██████  ███    ██ ███████ ██     ██████  ██████   ██████  ████████  ██████   ██████  ██████  ██
██   ██ ██    ██ ████   ██    ███  ██     ██   ██ ██   ██ ██    ██    ██    ██    ██ ██      ██    ██ ██
██████  ██    ██ ██ ██  ██   ███   ██     ██████  ██████  ██    ██    ██    ██    ██ ██      ██    ██ ██
██      ██    ██ ██  ██ ██  ███    ██     ██      ██   ██ ██    ██    ██    ██    ██ ██      ██    ██ ██
██       ██████  ██   ████ ███████ ██     ██      ██   ██  ██████     ██     ██████   ██████  ██████  ███████
*/

pragma solidity ^0.8.13;

contract Owners {
    event OwnerAdded(
        address indexed adder,
        address indexed owner,
        uint256 indexed timestamp
    );

    event OwnerRemoved(
        address indexed remover,
        address indexed owner,
        uint256 indexed timestamp
    );

    event OwnershipRenounced(uint256 timestamp);

    bool public renounced;

    address private masterOwner;
    mapping(address => bool) private ownerMap;
    address[] private ownerList;

    constructor() {
        masterOwner = msg.sender;
        ownerMap[msg.sender] = true;
        ownerList.push(msg.sender);
    }

    modifier onlyMasterOwner() {
        require(!renounced, "Ownership renounced");
        require(msg.sender == masterOwner);
        _;
    }

    modifier onlyOwners() {
        require(!renounced, "Ownership renounced");
        require(ownerMap[msg.sender], "Caller is not an owner");
        _;
    }

    /// @notice Return whether given address is one of the owners of this contract
    /// @param address_ Address to check
    /// @return True/False
    function isOwner(address address_) public view returns (bool) {
        return ownerMap[address_];
    }

    /// @notice Get all addresses of current owners
    /// @return List of owners
    function getOwners() external view returns (address[] memory) {
        return ownerList;
    }

    /// @notice Add a new owner, only the master owner can add
    /// @param address_ Address to add
    function addOwner(address address_) public onlyMasterOwner {
        ownerMap[address_] = true;
        ownerList.push(address_);
        emit OwnerAdded(msg.sender, address_, block.timestamp);
    }

    /// @notice Remove existing owner, only master owner can remove
    /// @param address_ Address to remove
    function removeOwner(address address_) public onlyMasterOwner {
        require(ownerMap[address_], "Address is not an owner");
        require(address_ != masterOwner, "Master owner can't be removed");
        uint256 lengthBefore = ownerList.length;
        for (uint256 i = 0; i < ownerList.length; i++) {
            if (ownerList[i] == address_) {
                ownerMap[address_] = false;
                for (uint256 j = i; j < ownerList.length - 1; j++) {
                    ownerList[i] = ownerList[i + 1];
                }
                ownerList.pop();
                break;
            }
        }
        uint256 lengthAfter = ownerList.length;
        require( // Sanity check
            lengthAfter < lengthBefore,
            "Something went wrong removing owners"
        );
        emit OwnerRemoved(msg.sender, address_, block.timestamp);
    }

    /// @notice Let master owner renounce contract
    /// @param check Requires "give" as a parameter to prevent accidental renouncing
    function renounceOwnership(string memory check) external onlyMasterOwner {
        string memory checkAgainst = "confirm";
        require(
            keccak256(bytes(check)) == keccak256(bytes(checkAgainst)),
            "Can't renounce without 'confirm' as a parameter"
        );
        renounced = true;
        emit OwnershipRenounced(block.timestamp);
    }
}

contract PauseOwners is Owners {
    bool public isPaused;

    mapping(address => bool) public pauseExempt;

    function pauseGuard(address[3] memory addresses) internal view virtual {
        bool isExempt = false;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (isOwner(addresses[i]) || pauseExempt[addresses[i]]) {
                isExempt = true;
                break;
            }
        }
        require(isExempt, "Paused");
    }

    function modifyPauseExempt(address address_, bool value)
        external
        onlyOwners
    {
        pauseExempt[address_] = value;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IPancakeSwapPair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeSwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPancakeSwapFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

contract DividendDistributor {
    address _token;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    // Testnet BUSD
    // IERC20 rewardToken = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    // Mainnet BUSD
    IERC20 rewardToken = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IPancakeSwapRouter router;

    address[] shareholders;
    mapping(address => uint256) shareholderIndexes;
    mapping(address => uint256) shareholderClaims;

    mapping(address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public currentIndex;

    uint256 public dividendsPerShareAccuracyFactor = 10**36;
    uint256 public minPeriod = 1 hours;
    uint256 public minDistribution = 10 * (10**18);

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token);
        _;
    }

    constructor(address _router) {
        router = _router != address(0)
            ? IPancakeSwapRouter(_router)
            : IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _token = msg.sender;
    }

    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external onlyToken {
        if (shares[shareholder].amount > 0) {
            distributeDividend(shareholder);
        }

        if (amount > 0 && shares[shareholder].amount == 0) {
            addShareholder(shareholder);
        } else if (amount == 0 && shares[shareholder].amount > 0) {
            removeShareholder(shareholder);
        }

        totalShares -= shares[shareholder].amount + amount;
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(
            shares[shareholder].amount
        );
    }

    function deposit() external payable onlyToken {
        uint256 balanceBefore = rewardToken.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(rewardToken);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: msg.value
        }(0, path, address(this), block.timestamp);

        uint256 amount = rewardToken.balanceOf(address(this)) - balanceBefore;

        totalDividends += amount;
        dividendsPerShare +=
            (dividendsPerShareAccuracyFactor * amount) /
            totalShares;
    }

    function process(uint256 gas) external onlyToken {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            if (shouldDistribute(shareholders[currentIndex])) {
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed += (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    function shouldDistribute(address shareholder)
        internal
        view
        returns (bool)
    {
        return
            shareholderClaims[shareholder] + minPeriod < block.timestamp &&
            getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if (shares[shareholder].amount == 0) {
            return;
        }

        uint256 amount = getUnpaidEarnings(shareholder);
        if (amount > 0) {
            totalDistributed += amount;
            rewardToken.transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised =
                shares[shareholder].totalRealised +
                amount;
            shares[shareholder].totalExcluded = getCumulativeDividends(
                shares[shareholder].amount
            );
        }
    }

    function claimDividend() public {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder)
        public
        view
        returns (uint256)
    {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint256 shareholderTotalDividends = getCumulativeDividends(
            shares[shareholder].amount
        );
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if (shareholderTotalDividends <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalDividends - shareholderTotalExcluded;
    }

    function getShareholder(address _addr)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        Share memory _shareholder = shares[_addr];
        return (
            _shareholder.amount,
            _shareholder.totalExcluded,
            _shareholder.totalRealised
        );
    }

    function getCumulativeDividends(uint256 share)
        internal
        view
        returns (uint256)
    {
        return (share * dividendsPerShare) / dividendsPerShareAccuracyFactor;
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[
            shareholders.length - 1
        ];
        shareholderIndexes[
            shareholders[shareholders.length - 1]
        ] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract PonziProtocol is ERC20Detailed, PauseOwners {
    event LogRebase(uint256 indexed rebaseEpoch, uint256 totalSupply);
    event LogAddLiquidity(
        uint256 indexed timestamp,
        uint256 amountETH,
        uint256 amountToken
    );

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    uint256 private constant MAX_UINT256 = type(uint256).max;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address private constant ZERO = 0x0000000000000000000000000000000000000000;
    uint256 private constant DECIMAL_BASE = 10**5;
    uint256 private constant DECIMAL_RATE = 10**7;

    uint256 public constant maxTotalFee = 200;

    uint256 public buyLiquidityFee = 30;
    uint256 public buyTreasuryFee = 50;
    uint256 public buyDividendFee = 20;
    uint256 public buyTotalFee =
        buyLiquidityFee + buyTreasuryFee + buyDividendFee;

    uint256 public sellBurnFee = 80;
    uint256 public sellLiquidityFee = 40;
    uint256 public sellTreasuryFee = 50;
    uint256 public sellDividendFee = 30;
    uint256 public sellTotalFee =
        sellBurnFee + sellLiquidityFee + sellTreasuryFee + sellDividendFee;

    uint256 public feeDenominator = 1000;

    mapping(address => bool) public _isFeeExempt;

    address public autoLiquidityReceiver =
        0xc14E86AcF22eFA1b339dcdb076846e6c5C77aC3a;
    address public treasuryReceiver =
        0xDBE37121cAB0195259B5b0487E86EA1f5296f0F3;

    mapping(address => bool) public isDividendExempt;
    DividendDistributor public distributor;
    uint256 private distributorGas = 500000;

    IPancakeSwapRouter public router;
    address public pair;

    uint256 public rebaseInterval = 5 minutes;
    uint256 public rebaseRate = 2606; // 0.026065%
    uint256 public rebaseEpoch;

    bool public rebaseRateHalvingEnabled = true;
    uint256 public rebaseRateHalvingInterval = 365 days;
    uint256 public lastRebaseRateHalving;
    uint256 public rebaseRateDivisor = 2;

    uint256 public liquidityAddInterval = 5 minutes;

    mapping(address => bool) public botBlacklist;
    bool public antibotActivated;
    uint256 private antibotBlockEnd;
    uint256 private antibotTimeEnd;
    uint256 private maxTx = 1000 * DECIMAL_BASE;
    uint256 private maxWallet = 2000 * DECIMAL_BASE;

    bool public tradingEnabled;
    bool public swapEnabled = true;

    bool inSwap;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    bool public _autoRebase = false;
    bool public _autoAddLiquidity = false;

    uint256 public _lastRebasedTime;
    uint256 public _lastAddLiquidityTime;
    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;

    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 100000 * DECIMAL_BASE;
    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = 1000000000 * DECIMAL_BASE;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    constructor() ERC20Detailed("Ponzi Protocol", "PPCoin", uint8(5)) {
        isPaused = true;

        // Testnet
        // address routerAddress = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
        // Mainnet
        address routerAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

        router = IPancakeSwapRouter(routerAddress);
        pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );

        _allowedFragments[address(this)][address(router)] = type(uint256).max;

        distributor = new DividendDistributor(routerAddress);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonsPerFragment = TOTAL_GONS / _totalSupply;
        _gonBalances[msg.sender] = TOTAL_GONS;

        isDividendExempt[pair] = true;
        isDividendExempt[DEAD] = true;
        isDividendExempt[ZERO] = true;
        isDividendExempt[address(this)] = true;

        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[autoLiquidityReceiver] = true;
        _isFeeExempt[address(this)] = true;
    }

    function activateTrade() external onlyOwners {
        require(!tradingEnabled, "Trading is already activated");
        tradingEnabled = true;

        antibotBlockEnd = block.number + 2;
        antibotTimeEnd = block.timestamp + 300;
        _lastAddLiquidityTime = block.timestamp;
        _autoAddLiquidity = true;
        antibotActivated = true;
        isPaused = false;
    }

    function antibotGuard(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        if (block.timestamp < antibotTimeEnd) {
            if (block.number < antibotBlockEnd) {
                botBlacklist[sender] = true;
                return true;
            } else if (amount > maxTx) {
                return true;
            } else if (
                (amount + balanceOf(recipient)) > maxWallet && recipient != pair
            ) {
                return true;
            }
        } else {
            _autoRebase = true;
            uint256 timeNow = block.timestamp;
            _lastRebasedTime = timeNow;
            lastRebaseRateHalving = timeNow;
            antibotActivated = false;
        }
        return false;
    }

    function rebase() internal {
        if (inSwap) return;

        if (
            rebaseRateHalvingEnabled &&
            block.timestamp - lastRebaseRateHalving >= rebaseRateHalvingInterval
        ) {
            lastRebaseRateHalving = block.timestamp;
            rebaseRate /= rebaseRateDivisor;
            if (rebaseRate <= 4) {
                rebaseRateHalvingEnabled = false;
            }
        }

        uint256 timeSinceLastRebase = block.timestamp -
            (_lastRebasedTime + rebaseInterval);
        if (timeSinceLastRebase > 0) {
            uint256 rebasesMissed = (rebaseRate * timeSinceLastRebase) /
                rebaseInterval;
            uint256 timeAdjustedRebaseRate = rebaseRate + rebasesMissed;
            _totalSupply +=
                (_totalSupply * timeAdjustedRebaseRate) /
                DECIMAL_RATE;
        } else {
            _totalSupply +=
                (getCirculatingSupplyExcludingLiquidity() * rebaseRate) /
                DECIMAL_RATE;
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
            _autoRebase = false;
        }
        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        IPancakeSwapPair(pair).sync();
        rebaseEpoch += 1;
        _lastRebasedTime = block.timestamp;
        emit LogRebase(rebaseEpoch, _totalSupply);
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

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != MAX_UINT256) {
            _allowedFragments[from][msg.sender] -= value;
        }
        _transferFrom(from, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 gonAmount
    ) internal returns (bool) {
        _gonBalances[from] -= gonAmount;
        _gonBalances[to] += gonAmount;
        emit Transfer(from, to, gonAmount / _gonsPerFragment);
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (isPaused) {
            address[3] memory addresses = [sender, msg.sender, tx.origin];
            pauseGuard(addresses);
        }

        if (antibotActivated) {
            bool activated = antibotGuard(sender, recipient, amount);
            if (activated) {
                return false;
            }
        }
        require(
            !botBlacklist[sender] && !botBlacklist[recipient],
            "in_botBlacklist"
        );

        uint256 gonAmount = amount * _gonsPerFragment;
        if (inSwap || !tradingEnabled) {
            return _basicTransfer(sender, recipient, gonAmount);
        }

        if (shouldRebase()) {
            rebase();
        }

        if (shouldAddLiquidity()) {
            addLiquidity();
        }

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] -= gonAmount;
        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, gonAmount)
            : gonAmount;
        _gonBalances[recipient] += gonAmountReceived;

        if (!isDividendExempt[sender]) {
            try distributor.setShare(sender, balanceOf(sender)) {} catch {}
        }
        if (!isDividendExempt[recipient]) {
            try
                distributor.setShare(recipient, balanceOf(recipient))
            {} catch {}
        }

        try distributor.process(distributorGas) {} catch {}

        emit Transfer(sender, recipient, gonAmountReceived / _gonsPerFragment);
        return true;
    }

    function takeFee(address sender, uint256 gonAmount)
        internal
        returns (uint256)
    {
        uint256 feeAmount;
        uint256 treasuryFee;
        uint256 dividendFee;
        uint256 liquidityFee;
        if (sender == pair) {
            feeAmount = (gonAmount / feeDenominator) * buyTotalFee;
            treasuryFee = buyTreasuryFee;
            dividendFee = buyDividendFee;
            liquidityFee = buyLiquidityFee;
        } else {
            feeAmount = (gonAmount / feeDenominator) * sellTotalFee;
            treasuryFee = sellTreasuryFee;
            dividendFee = sellDividendFee;
            liquidityFee = sellLiquidityFee;
            _gonBalances[DEAD] += (gonAmount / feeDenominator) * sellBurnFee;
        }

        _gonBalances[address(this)] +=
            (gonAmount / feeDenominator) *
            (treasuryFee + dividendFee);

        _gonBalances[autoLiquidityReceiver] +=
            (gonAmount / feeDenominator) *
            liquidityFee;

        emit Transfer(sender, address(this), feeAmount / _gonsPerFragment);
        return gonAmount - feeAmount;
    }

    function addLiquidity() internal swapping {
        uint256 autoLiquidityAmount = _gonBalances[autoLiquidityReceiver] /
            _gonsPerFragment;
        _gonBalances[address(this)] += _gonBalances[autoLiquidityReceiver];
        _gonBalances[autoLiquidityReceiver] = 0;
        uint256 amountToLiquify = autoLiquidityAmount / 2;
        uint256 amountToSwap = autoLiquidityAmount - amountToLiquify;
        uint256 amountETHLiquidity = swapToETH(amountToSwap);
        if (amountToLiquify > 0 && amountETHLiquidity > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
            emit LogAddLiquidity(
                block.timestamp,
                amountETHLiquidity,
                amountToLiquify
            );
        }
        _lastAddLiquidityTime = block.timestamp;
    }

    function swapBack() internal swapping {
        uint256 amountToSwap = _gonBalances[address(this)] / _gonsPerFragment;
        uint256 amountETH = swapToETH(amountToSwap);
        if (amountETH > 0) {
            uint256 treasuryFee = (buyTreasuryFee + sellTreasuryFee) / 2;
            uint256 dividendFee = (buyDividendFee + sellDividendFee) / 2;
            uint256 amountFee = treasuryFee + dividendFee;
            payable(treasuryReceiver).call{
                value: (amountETH * treasuryFee) / amountFee,
                gas: 30000
            }("");
            try
                distributor.deposit{
                    value: (amountETH * dividendFee) / amountFee
                }()
            {} catch {}
        }
    }

    function manualWithdraw() external swapping onlyOwners {
        uint256 amountToSwap = _gonBalances[address(this)] / _gonsPerFragment;
        uint256 amountETH = swapToETH(amountToSwap);
        if (amountETH > 0) {
            payable(treasuryReceiver).call{value: amountETH, gas: 30000}("");
        }
    }

    function swapToETH(uint256 amountToSwap) private returns (uint256) {
        if (amountToSwap == 0) {
            return 0;
        }
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
        return address(this).balance - balanceBefore;
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        return (pair == from || pair == to) && !_isFeeExempt[from];
    }

    function shouldRebase() internal view returns (bool) {
        return
            _autoRebase &&
            msg.sender != pair &&
            !inSwap &&
            block.timestamp >= (_lastRebasedTime + rebaseInterval);
    }

    function shouldAddLiquidity() internal view returns (bool) {
        return
            _autoAddLiquidity &&
            msg.sender != pair &&
            !inSwap &&
            block.timestamp >= (_lastAddLiquidityTime + liquidityAddInterval);
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && msg.sender != pair;
    }

    function setRebaseSettings(
        bool enabled,
        uint256 interval,
        uint256 rate
    ) external onlyOwners {
        _autoRebase = enabled;
        rebaseInterval = interval;
        rebaseRate = rate;
        _lastRebasedTime = block.timestamp;
    }

    function setRebaseHalvingSettings(bool enabled, uint256 interval)
        external
        onlyOwners
    {
        rebaseRateHalvingEnabled = enabled;
        rebaseRateHalvingInterval = interval;
        _lastRebasedTime = block.timestamp;
    }

    function setAutoAddLiquiditySettings(bool enabled, uint256 interval)
        external
        onlyOwners
    {
        _autoAddLiquidity = enabled;
        liquidityAddInterval = interval;
        _lastAddLiquidityTime = block.timestamp;
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
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

    function setIsDividendExempt(address holder, bool exempt)
        external
        onlyOwners
    {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;

        if (exempt) {
            distributor.setShare(holder, 0);
        } else {
            distributor.setShare(holder, balanceOf(holder));
        }
    }

    function setDividendDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution
    ) external onlyOwners {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDividendDistributorGas(uint256 gas) external onlyOwners {
        require(gas < 750000, "Gas must be lower than 750000");
        distributorGas = gas;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS - _gonBalances[DEAD] - _gonBalances[ZERO]) /
            _gonsPerFragment;
    }

    function getCirculatingSupplyExcludingLiquidity()
        public
        view
        returns (uint256)
    {
        return
            (TOTAL_GONS -
                _gonBalances[DEAD] -
                _gonBalances[ZERO] -
                _gonBalances[pair]) / _gonsPerFragment;
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function manualSync() external {
        IPancakeSwapPair(pair).sync();
    }

    function setFeeReceivers(
        address _buybackReceiver,
        address _autoLiquidityReceiver,
        address _treasuryReceiver
    ) external onlyOwners {
        _buybackReceiver = _buybackReceiver;
        autoLiquidityReceiver = _autoLiquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function setFeeExempt(address _addr, bool _flag) external onlyOwners {
        _isFeeExempt[_addr] = _flag;
    }

    function setBuyFees(
        uint256 _liquidityFee,
        uint256 _dividendFee,
        uint256 _treasuryFee
    ) external onlyOwners {
        require(_liquidityFee + _dividendFee + _treasuryFee <= maxTotalFee);
        buyLiquidityFee = _liquidityFee;
        buyDividendFee = _dividendFee;
        buyTreasuryFee = _treasuryFee;
    }

    function setSellFees(
        uint256 _burnFee,
        uint256 _liquidityFee,
        uint256 _dividendFee,
        uint256 _treasuryFee
    ) external onlyOwners {
        require(
            _burnFee + _liquidityFee + _dividendFee + _treasuryFee <=
                maxTotalFee
        );
        sellBurnFee = _burnFee;
        sellLiquidityFee = _liquidityFee;
        sellDividendFee = _dividendFee;
        sellTreasuryFee = _treasuryFee;
    }

    function getLiquidityBacking(uint256 accuracy)
        public
        view
        returns (uint256)
    {
        uint256 liquidityBalance = _gonBalances[pair] / _gonsPerFragment;
        return (accuracy * (liquidityBalance * 2)) / getCirculatingSupply();
    }

    function setBotBlacklist(address _address, bool _flag) external onlyOwners {
        if (isContract(_address) && _address != pair) {
            botBlacklist[_address] = _flag;
        } else {
            require(
                !_flag,
                "Can only disable blacklist for user owner addresses"
            );
            botBlacklist[_address] = _flag;
        }
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _gonBalances[account] / _gonsPerFragment;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    receive() external payable {}
}

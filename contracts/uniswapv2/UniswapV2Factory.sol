// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory {

    //Global Variables used by all swap pairs, managers, and oracles
    address public override feeToSetter;
    address public override migrator;
    address public override router;
    address public override governor;//Should never change
    address public override weth;//Should never change
    address public override wbtc;//Should never change
    address public override gfi;//Should never change
    address public override pathOracle;
    address public override priceOracle;
    address public override earningsManager;
    address public override feeManager;
    address public override dustPan;
    bool public override paused;
    uint public override slippage;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(UniswapV2Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(router != address(0), "Gravity Finance: Router not set");
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        UniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setMigrator(address _migrator) external override {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        migrator = _migrator;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setRouter(address _router) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        router = _router;
    }

    function setGovernor(address _governor) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        governor = _governor;
    }
    function setWETH(address _weth) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        weth = _weth;
    }
    function setWBTC(address _wbtc) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        wbtc = _wbtc;
    }
    function setGFI(address _gfi) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        gfi = _gfi;
    }
    function setPathOracle(address _pathOracle) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        pathOracle = _pathOracle;
    }
    function setPriceOracle(address _priceOracle) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        priceOracle = _priceOracle;
    }
    function setEarningsManager(address _earningsManager) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        earningsManager = _earningsManager;
    }
    function setFeeManager(address _feeManager) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeManager = _feeManager;
    }
    function setDustPan(address _dustPan) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        dustPan = _dustPan;
    }
    function setPaused(bool _paused) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        paused = _paused;
    }
    function setSlippage(uint _slippage) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        slippage = _slippage;
    }

}

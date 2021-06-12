// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IUniswapV2Factory.sol';

/*
* NOTE OWNER SHOULD CALL alterPath(weth, wbtc) after deployment to set the final path properly
*/
contract PathOracle is Ownable {
    mapping(address => address) public pathMap;
    address[] public favoredAssets;
    uint public favoredLength;
    address public FACTORY_ADDRESS;
    IUniswapV2Factory Factory;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;

    struct node{
        address token;
        bool notLeaf;
    }

    constructor(address[] memory _favored, uint _favoredLength, address weth, address wbtc) {
        favoredAssets = _favored;
        favoredLength = _favoredLength;
        WETH_ADDRESS = weth;
        WBTC_ADDRESS = wbtc;
    }

    function alterPath(address fromAsset, address toAsset) external onlyOwner {
        pathMap[fromAsset] = toAsset;
    }

    function stepPath(address from) public view returns(address to){
        to = pathMap[from];
    }

    function setFactory(address _address) external onlyOwner {
        FACTORY_ADDRESS = _address;
        Factory = IUniswapV2Factory(FACTORY_ADDRESS);
    }

    function updateSwapPath(address token0, address token1) external view returns(address[10] memory swapPath, uint swapCount){
        if(stepPath(token0) == token1){
            swapPath[0] = token0;
            swapPath[1] = token1;
        }
        else if(stepPath(token1) == token0){
            swapPath[0] = token1;
            swapPath[1] = token0;
        }
        else{
            require(false, "Path does not exist!");
        }
        bool done;
        uint i = 2;
        swapCount = 2;
        while (i < 10){ //Max amount of assets in the swap is 10
            if(!done){
                if(swapPath[i-1] == WETH_ADDRESS || swapPath[i-1] == WBTC_ADDRESS){//If the previous path went to wETH or wBTC, then set done to true, this makes it so that the next iteration adds address(0) as the path
                    done = true;
                }
                swapPath[i] = stepPath(swapPath[i-1]);
                swapCount++;
            }
            else {
                swapPath[i] = address(0);// was i + 1
            }
            i++;
        }
    }


    /**
    * @dev called by newly created pairs, basically check if either of the pairs are in the favored list, or if they have a pair with a favored list asset
    **/
    function appendPath(address token0, address token1) external {
        bool inFavored;
        //First Check if either of the tokens are in the favored list
        for (uint i=0; i < favoredLength; i++){
            if (token0 == favoredAssets[i]){
                pathMap[token1] = token0; //Swap token1 for token0
                inFavored = true;
                break;
            }

            else if (token1 == favoredAssets[i]){
                pathMap[token0] = token1; //Swap token0 for token1
                inFavored = true;
                break;
            }
        }
        //If neither of the tokens are in the favored list, then see if either of them have pairs with a token in the favored list
        if (!inFavored){
            for (uint i=0; i < favoredLength; i++){
                if (Factory.getPair(token0, favoredAssets[i]) != address(0)){
                    pathMap[token1] = token0; //Swap token1 for token0
                    pathMap[token0] = favoredAssets[i];
                    break;
                }

                else if (Factory.getPair(token1, favoredAssets[i]) != address(0)){
                    pathMap[token0] = token1; //Swap token0 for token1
                    pathMap[token1] = favoredAssets[i];
                    break;
                }
            }
        }
    }
}
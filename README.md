#Current Test Addresses:

Gravity Token Address: 0xB16aeBDCccf3Bf4166b6Cc8A7fbb37D81B2a650C

WETH Address: 0x3C68CE8504087f89c640D02d133646d98e64ddd9

Gravity IDO Address: 0xEaEC3F5A3d87bFd10DD5159b030Ac8F4EC842840

IDO IOU Token Address:  0xF4ccD1b21611c3Cb24fdFd683e2B9C1C9542dD48

Locking Address:  0x652875E267443d5616102f80A0ecE3956894F29e

Contract Owner Address:  0xeb678812778B68a48001B4A9A4A04c4924c33598

#IDO Times

Start: 1620852463

End: 1620938863

##How to install
run git clone https://github.com/crispymangoes/GravityFinance.git

cd GravityFinance

run npm install

run npm audit fix // if needed

Now you should be able to run npx hardhat to see all the hardhat options

run npx hardhat compile

run npx hardhat test

run npx hardhat run scripts/deploy.js

^^^above command has an optional network command --network mumbai

That command would deploy the scripts onto the mumbai network
Test Output

  GravityIDO presale functional test
    ✓ Should return IOU address
    ✓ setWETH_ADDRESS() should revert when caller is not owner
    ✓ setWETH_ADDRESS() should allow owner to change it before sale starts
    ✓ setGFI_ADDRESS() should revert when caller is not owner
    ✓ setGFI_ADDRESS() should allow owner to change it before sale starts
    ✓ withdrawAll() should allow owner to call it as long as no IOUs have been minted
    ✓ withdrawAll() should revert when caller is not owner
    ✓ withdraw() should revert when caller is not owner
    ✓ withdraw() should revert when sale has not begun
    ✓ buyStake() should revert when sale has not begun
    ✓ claimStake() should revert when sale has not begun

  GravityIDO during sale functional test
    ✓ setWETH_ADDRESS() should revert when IDO has already started
    ✓ setGFI_ADDRESS() should revert when IDO has already started
    ✓ withdraw() should revert when sale is ongoing
    ✓ claimStake() should revert when sale is ongoing
    ✓ buyStake() should revert when IDO contract does not hold enough GFI to cover the sale
    ✓ buyStake() should revert when _amount is 0
    ✓ buyStake() should revert when WETH transferFrom fails
    ✓ buyStake() should accept WETH and send caller IOU tokens
    ✓ buyStake() should revert if _amount > 0.5
    ✓ buyStake() should revert if two calls from same caller total _amount > 0.5 
    ✓ withdrawAll() should revert if IOU totalSupply() > 0

  GravityIDO after sale functional test UNDER SUBSCRIBED
    ✓ buyStake() should revert if called after sale end
    ✓ claimStake() should revert if caller has no IOUs to claim
    ✓ claimStake() should revert if IOU transferFrom fails
    ✓ claimStake() should revert if called before end of 30 min setup window
    ✓ claimStake() should accept 0.5 GFI_IDO, burn it, and return 20,000 GFI to caller
    ✓ withdraw() should callable by owner. 0.5WETH should go to Treasury, and 39,980,000 GFI should Promotion fund

  GravityIDO after sale functional test OVER SUBSCRIBED
    ✓ claimStake() should accept 0.5 GFI_IDO from 3 users, burn it, and return 13,333 GFI, and 0.166 WETH to each caller
    ✓ withdraw() should callable by owner. 0.5WETH should go to Treasury, and 39,980,000 GFI should Promotion fund

  IOU Token tests
    ✓ mintIOU() should revert if called by any address except for IDO address
    ✓ burnIOU() should revert if called by any address except for IDO address

  Locking Contract functional test
    ✓ claimGFI() should revert if called before vesting period is over
    ✓ claimGFI() should work if vesting period is over
    ✓ claimGFI() should revert if caller has no GFI to claim

·------------------------------------|---------------------------|--------------|-----------------------------·
|        Solc version: 0.6.6         ·  Optimizer enabled: true  ·  Runs: 1000  ·  Block limit: 12450000 gas  │
·····································|···························|··············|······························
|  Methods                                                                                                    │
·················|···················|·············|·············|··············|···············|··············
|  Contract      ·  Method           ·  Min        ·  Max        ·  Avg         ·  # calls      ·  usd (avg)  │
·················|···················|·············|·············|··············|···············|··············
|  GravityIDO    ·  buyStake         ·     113320  ·     179632  ·      151941  ·           15  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityIDO    ·  claimStake       ·      71678  ·     107325  ·       94663  ·            4  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityIDO    ·  setGFI_ADDRESS   ·          -  ·          -  ·       33319  ·            1  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityIDO    ·  setWETH_ADDRESS  ·          -  ·          -  ·       36110  ·            1  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityIDO    ·  withdraw         ·      87244  ·     109965  ·       98605  ·            2  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityIDO    ·  withdrawAll      ·          -  ·          -  ·       62309  ·            1  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityToken  ·  approve          ·      46249  ·      46261  ·       46260  ·           35  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  GravityToken  ·  transfer         ·      53764  ·      53776  ·       53773  ·           14  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  IOUToken      ·  approve          ·      46263  ·      46275  ·       46272  ·            4  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  Locking       ·  addUser          ·          -  ·          -  ·      164872  ·           35  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  Locking       ·  claimGFI         ·          -  ·          -  ·       48052  ·            1  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  MockToken     ·  approve          ·      46262  ·      46274  ·       46273  ·           17  ·          -  │
·················|···················|·············|·············|··············|···············|··············
|  Deployments                       ·                                          ·  % of limit   ·             │
·····································|·············|·············|··············|···············|··············
|  GravityIDO                        ·    2845724  ·    2845813  ·     2845744  ·       22.9 %  ·          -  │
·····································|·············|·············|··············|···············|··············
|  GravityToken                      ·          -  ·          -  ·     1140976  ·        9.2 %  ·          -  │
·····································|·············|·············|··············|···············|··············
|  Locking                           ·    1175962  ·    1176010  ·     1176006  ·        9.4 %  ·          -  │
·····································|·············|·············|··············|···············|··············
|  MockToken                         ·          -  ·          -  ·      767212  ·        6.2 %  ·          -  │
·------------------------------------|-------------|-------------|--------------|---------------|-------------·

  35 passing (12s)

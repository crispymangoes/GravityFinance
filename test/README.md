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
    ✓ buyStake() should accept WETH and send caller IOU tokens (73ms)
    ✓ buyStake() should revert if _amount > 0.5
    ✓ buyStake() should revert if two calls from same caller total _amount > 0.5  (57ms)
    ✓ withdrawAll() should revert if IOU totalSupply() > 0 (60ms)

  GravityIDO after sale functional test UNDER SUBSCRIBED
    ✓ buyStake() should revert if called after sale end
    ✓ claimStake() should revert if caller has no IOUs to claim
    ✓ claimStake() should revert if IOU transferFrom fails
    ✓ claimStake() should accept 0.5 GFI_IDO, burn it, and return 20,000 GFI to caller (77ms)
    ✓ withdraw() should callable by owner. 0.5WETH should go to Treasury, and 39,980,000 GFI should Promotion fund

GravityIDO after sale functional test OVER SUBSCRIBED
    ✓ claimStake() should accept 0.5 GFI_IDO from 3 users, burn it, and return 20,000 GFI to caller (163ms)
    ✓ withdraw() should callable by owner. 0.5WETH should go to Treasury, and 39,980,000 GFI should Promotion fund


  29 passing (8s)


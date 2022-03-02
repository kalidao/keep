const { BigNumber } = require("ethers")
const chai = require("chai")
const { expect } = require("chai")

chai.should()

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals))
}

describe("ClubSig", function () {
    let ClubSig // ClubSig contract
    let clubSig // ClubSig contract instance

    let Token0 // token0 contract
    let token0 // token0 contract instance

    let alice // signerA
    let bob // signerB
    let carol // signerC
  
    beforeEach(async () => {
      ;[alice, bob, carol] = await ethers.getSigners()
  
      ClubSig = await ethers.getContractFactory("ClubSig")
      clubSig = await ClubSig.deploy()
      await clubSig.deployed()

      Token0 = await ethers.getContractFactory("ERC20")
      token0 = await Token0.deploy(
        "Wrapped Ether",
        "WETH",
        alice.address,
        getBigNumber(1000)
      )
      await token0.deployed()
    })
    
    it("Should initialize multi-sig", async function () { 
        clubSig.init(
            [alice.address, bob.address],
            [0, 1],
            [100, 100],
            2,
            false,
            "BASE"
        )
    })
})

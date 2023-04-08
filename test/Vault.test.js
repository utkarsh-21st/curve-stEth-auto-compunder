// test done on block number: 16948000

const { expect } = require("chai")
const { deployContract } = require("../scripts/deploy")
const helpers = require("@nomicfoundation/hardhat-network-helpers")
const { parseUnits } = require("ethers/lib/utils")
const { BigNumber } = require("ethers")

const config = {
  vaultContractName: "Vault",
  strategyContractName: "Strategy",
  wantWhaleAddress: "0x41318419CFa25396b47A94896FfA2C77c6434040",
  bigDeposit: parseUnits("10000", 'ether'),
  lowDeposit: parseUnits("1", '10'),
}

const MAX_UINT = BigNumber.from(2).pow(256).sub(1)

describe("Test", () => {
  let vault, strategy, reward1, reward2, native, want, lpReceipt
  let acc1, acc2, wantWhaleSigner
  let snapshotBefore, snapshot

  before(async () => {
    var deployAddresses = await deployContract();
    [acc1, acc2] = await ethers.getSigners();
    vault = await ethers.getContractAt(config.vaultContractName, deployAddresses["Vault"]);;
    strategy = await ethers.getContractAt(config.strategyContractName, await vault.strategy())
    reward1 = await ethers.getContractAt(
      "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
      strategy.reward1()
    )
    reward2 = await ethers.getContractAt(
      "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
      strategy.reward2()
    )
    native = await ethers.getContractAt(
      "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
      await strategy.native()
    )
    want = await ethers.getContractAt(
      "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
      await strategy.want()
    )
    lpReceipt = await ethers.getContractAt(
      "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
      await strategy.lpReceipt()
    )

    await helpers.impersonateAccount(config.wantWhaleAddress)
    wantWhaleSigner = await ethers.getSigner(config.wantWhaleAddress)

    console.log("want balance of whale before", await want.balanceOf(wantWhaleSigner.address))
    await want.connect(wantWhaleSigner).transfer(acc1.address, config.bigDeposit.mul(4))
    await want.connect(wantWhaleSigner).transfer(acc2.address, config.bigDeposit.mul(4))
    console.log("want balance of whale after", await want.balanceOf(wantWhaleSigner.address))

    snapshotBefore = await helpers.takeSnapshot()
  })

  after(async function () {
    await snapshotBefore.restore()
  })

  beforeEach(async function () {
    snapshot = await helpers.takeSnapshot()
  })

  afterEach(async function () {
    await snapshot.restore()
  })

  const deposit = async () => {
    await want.connect(acc1).approve(vault.address, MAX_UINT)
    await want.connect(acc2).approve(vault.address, MAX_UINT)

    const vaultReceiptAcc1Before = await vault.balanceOf(acc1.address)
    const vaultReceiptAcc2Before = await vault.balanceOf(acc2.address)
    const vaultBalanceBefore = await vault.balance()
    const balanceOfGaugeBefore = await strategy.balanceOfGauge()

    await vault.connect(acc1).deposit(config.bigDeposit)
    console.log('acc1 Big deposit')
    const vaultReceiptAcc1After = await vault.balanceOf(acc1.address)

    await vault.connect(acc2).deposit(config.lowDeposit)
    console.log('acc2 low deposited')
    const vaultReceiptAcc2After = await vault.balanceOf(acc2.address)

    const vaultBalanceAfter = await vault.balance()
    const balanceOfGaugeAfter = await strategy.balanceOfGauge()

    expect(vaultReceiptAcc1After).to.be.above(vaultReceiptAcc1Before)
    expect(vaultReceiptAcc2After).to.be.above(vaultReceiptAcc2Before)
    expect(vaultBalanceAfter).to.be.above(vaultBalanceBefore)
    expect(balanceOfGaugeAfter).to.be.above(balanceOfGaugeBefore)
  }

  it("sanity checkpoint", async () => {
    expect(1).to.equal(1)
  })

  it("deposit", async () => {
    await deposit()
  })

  it("harvest", async () => {
    const feeRecipient = await strategy.feeRecipient()
    await deposit()

    console.log('advance 1 hour in time')
    await helpers.time.increase(3600)

    const feeRecepientNativeBalanceBefore = await native.balanceOf(feeRecipient)
    const balanceOfGaugeBefore = await strategy.balanceOfGauge()

    console.log('harvesting...')
    await (await strategy.harvest()).wait()

    const feeRecepientNativeBalanceAfter = await native.balanceOf(feeRecipient)
    const balanceOfGaugeAfter = await strategy.balanceOfGauge()

    expect(feeRecepientNativeBalanceAfter).to.be.above(feeRecepientNativeBalanceBefore)
    expect(balanceOfGaugeAfter).to.be.above(balanceOfGaugeBefore)

    console.log('advance 10 hours in time')
    await helpers.time.increase(36000)

    const feeRecepientNativeBalanceBefore2 = await native.balanceOf(feeRecipient)
    const balanceOfGaugeBefore2 = await strategy.balanceOfGauge()

    console.log('harvesting...')
    await (await strategy.harvest()).wait()

    const feeRecepientNativeBalanceAfter2 = await native.balanceOf(feeRecipient)
    const balanceOfGaugeAfter2 = await strategy.balanceOfGauge()

    expect(feeRecepientNativeBalanceAfter2).to.be.above(feeRecepientNativeBalanceBefore2)
    expect(balanceOfGaugeAfter2).to.be.above(balanceOfGaugeBefore2)

    await (await strategy.harvest()).wait()
  })

  it("withdraw", async () => {
    await deposit()

    const getState = async () => {
      return [await vault.balanceOf(acc1.address),
      await vault.balanceOf(acc2.address),
      await want.balanceOf(acc1.address),
      await want.balanceOf(acc2.address),
      await vault.balance(),
      await strategy.balanceOfGauge()]
    }

    let vaultReceiptAcc1Before, vaultReceiptAcc2Before, wantBalanceAcc1Before, wantBalanceAcc2Before,
      vaultBalanceBefore, balanceOfGaugeBefore;

    let vaultReceiptAcc1After, vaultReceiptAcc2After, wantBalanceAcc1After, wantBalanceAcc2After,
      vaultBalanceAfter, balanceOfGaugeAfter;

    [vaultReceiptAcc1Before, vaultReceiptAcc2Before, wantBalanceAcc1Before, wantBalanceAcc2Before,
      vaultBalanceBefore, balanceOfGaugeBefore] = await getState();

    console.log("acc1 withdraws");
    await vault.connect(acc1).withdraw(vaultReceiptAcc1Before.mul(1).div(100));
    console.log("acc2 withdraws");
    await vault.connect(acc2).withdraw(vaultReceiptAcc2Before.mul(80).div(100));

    [vaultReceiptAcc1After, vaultReceiptAcc2After, wantBalanceAcc1After, wantBalanceAcc2After,
      vaultBalanceAfter, balanceOfGaugeAfter] = await getState();

    expect(vaultReceiptAcc1After).to.be.below(vaultReceiptAcc1Before);
    expect(vaultReceiptAcc2After).to.be.below(vaultReceiptAcc2Before);
    expect(wantBalanceAcc1After).to.be.above(wantBalanceAcc1Before);
    expect(wantBalanceAcc2After).to.be.above(wantBalanceAcc2Before);
    expect(vaultBalanceAfter).to.be.below(vaultBalanceBefore);
    expect(balanceOfGaugeAfter).to.be.below(balanceOfGaugeBefore);

    [vaultReceiptAcc1Before, vaultReceiptAcc2Before, wantBalanceAcc1Before, wantBalanceAcc2Before,
      vaultBalanceBefore, balanceOfGaugeBefore] = await getState();

    console.log("acc1 withdraws all");
    await (await vault.connect(acc1).withdrawAll()).wait();
    console.log("acc2 withdraws all");
    await (await vault.connect(acc2).withdrawAll()).wait();

    [vaultReceiptAcc1After, vaultReceiptAcc2After, wantBalanceAcc1After, wantBalanceAcc2After,
      vaultBalanceAfter, balanceOfGaugeAfter] = await getState();


    console.log('vaultBalanceAfter, balanceOfGaugeAfter', vaultBalanceAfter, balanceOfGaugeAfter)
    expect(vaultReceiptAcc1After).to.be.equal(0);
    expect(vaultReceiptAcc2After).to.be.equal(0);
    expect(wantBalanceAcc1After).to.be.above(wantBalanceAcc1Before);
    expect(wantBalanceAcc2After).to.be.above(wantBalanceAcc2Before);
    expect(vaultBalanceAfter).to.be.below(parseUnits("1", '10'));
    expect(balanceOfGaugeAfter).to.be.below(parseUnits("1", '10'));
  })
})

const { ethers } = require("hardhat")

const pool = "0xdc24316b9ae028f1497c275eb9192a3ea0f67022"
const reward1Pool = "0x9409280dc1e6d33ab7a8c6ec03e5763fb61772b5"
const reward2Pool = "0x8301ae4fc9c624d1d396cbdaa1ed877821d7c511"
const gauge = "0x182b723a58739a9c974cfdb385ceadb237453c28"
const minter = "0xd061d61a4d941c39e5453435b6345dc261c2fce0"
const feeRecipient = "0xAD76AE0881358Dbe61127Ffaa87836F50cceBA44"

async function main() {
  await deployContract()
}

async function deployContract() {
  let deployed = {}
  console.log('deploying strategy...')
  const strategy = await ethers.deployContract('Strategy', [
    pool,
    reward1Pool,
    reward2Pool,
    gauge,
    minter,
    feeRecipient
  ])
  await strategy.deployed()

  console.log('deploying vault...')
  const vault = await ethers.deployContract('Vault', [
    strategy.address,
    'Vault Reciept',
    'vaultReciept',
    86400000
  ])
  await vault.deployed()

  await (await strategy.setVault(vault.address)).wait()

  deployed['Strategy'] = strategy.address
  deployed['Vault'] = vault.address

  console.log(deployed)
  return deployed
}

if (require.main == module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
}

module.exports = { deployContract }
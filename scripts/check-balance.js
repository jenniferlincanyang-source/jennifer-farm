const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const JENNIFER = "0x4a0ad8f5083eb382bb4a4a334f1774955adce758";
  const FARM = "0x642511132b621C3e962C8681D9D46138B6b3EeAB";

  const [deployer] = await hre.ethers.getSigners();
  const token = new hre.ethers.Contract(JENNIFER, [
    "function balanceOf(address) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)"
  ], deployer);

  const balance = await token.balanceOf(deployer.address);
  const decimals = await token.decimals();
  const symbol = await token.symbol();

  console.log("钱包地址:", deployer.address);
  console.log(`${symbol} 余额:`, hre.ethers.formatUnits(balance, decimals));
}

main().catch(console.error);

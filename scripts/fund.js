const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const JENNIFER = "0x4a0ad8f5083eb382bb4a4a334f1774955adce758";
  const FARM = "0x642511132b621C3e962C8681D9D46138B6b3EeAB";

  const [deployer] = await hre.ethers.getSigners();
  const token = new hre.ethers.Contract(JENNIFER, [
    "function approve(address,uint256) returns (bool)",
    "function allowance(address,address) view returns (uint256)"
  ], deployer);

  const amount = hre.ethers.parseUnits("1000000", 18); // 100万 JENNIFER
  const duration = 180 * 24 * 3600; // 180天 = 15552000秒

  // 1. Approve
  console.log("授权 JENNIFER 给 Farm 合约...");
  const approveTx = await token.approve(FARM, amount);
  await approveTx.wait();
  console.log("授权成功!");

  // 2. Fund
  const farm = new hre.ethers.Contract(FARM, [
    "function fund(uint256,uint256)"
  ], deployer);

  console.log("注入 1,000,000 JENNIFER，持续 180 天...");
  const fundTx = await farm.fund(amount, duration);
  await fundTx.wait();
  console.log("挖矿已启动!");
  console.log("每秒产出:", Number(amount / BigInt(duration)) / 1e18, "JENNIFER");
}

main().catch(console.error);

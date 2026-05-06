{ config, lib, ... }:

{
  # Fix for cursor disappearing after suspend/resume on Intel TigerLake-LP (Iris Xe)
  boot.kernelParams = [ "i915.enable_psr=0" ];

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}

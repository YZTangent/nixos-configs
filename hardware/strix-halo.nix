# Strix Halo (Ryzen AI MAX+ 395 / Radeon 8060S) GPU memory & IOMMU tuning.
#
# Strategy: unified memory. The BIOS "GPU memory" allocation is set to the
# minimum (512 MiB), so the iGPU draws up to 124 GiB of *system* RAM on demand
# through the GTT, instead of a permanently carved-out 64 GiB that the CPU can
# never see.
#
# The two caps are partners:
#   - amdgpu.gttsize caps what the amdgpu driver may allocate as GTT (MiB).
#   - ttm.pages_limit caps what the kernel DRM memory manager may pin
#     (pages x 4 KiB), enforcing the same budget at the lower layer.
# Both must agree or allocation fails.
#
# amd_iommu=off removes per-DMA page-table translation for unified-memory
# traffic (measured 5-12% faster than iommu=pt; see kyuz0/amd-strix-halo-toolboxes
# issue #66). Tradeoff: no DMA isolation and no VFIO passthrough.
#
# Reference: https://github.com/kyuz0/amd-strix-halo-toolboxes#host-configuration
# (tested on Framework Desktop, Ryzen AI MAX+ 395, 128 GB RAM, 512 MiB BIOS carve-out)
#
# Headroom note: this caps the GPU at 124 GiB, leaving ~4 GiB of RAM guaranteed
# for the OS at the extreme. A desktop running niri + k3s + docker may prefer
# ~110 GiB (gttsize=112640, pages_limit=28835840) if huge-model runs ever starve
# the OS; tune consciously.
{ ... }:

{
  boot.kernelParams = [
    "amd_iommu=off"
    "amdgpu.gttsize=126976"
    "ttm.pages_limit=32505856"
  ];
}

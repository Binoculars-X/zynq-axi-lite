docker run --rm `
    -v "C:\repos\_Neuro\temp\petalinux-build\build.sh:/home/builder/build.sh" `
    -v "C:\repos\_Neuro\temp\petalinux-output:/output" `
    -v "C:\repos\_Neuro\neuro-fabric\fpga\scripts\transformer_train_zcu102_axi_out\transformer_train_zcu102_axi.xsa:/tmp/transformer_train_zcu102_axi.xsa:ro" `
    petalinux-zcu102:2026.1

#![no_std]
#![no_main]

use plankton::layout::STAGE3_START;
use plankton::{dev::DiskRecord, print, println};
use stage_2nd::ParamTable;

#[link_section = ".table"]
#[no_mangle]
pub static mut PARAM: ParamTable = ParamTable {
    cmd_line: [0u8; 120],
    stage3_size: 0,
    stage4_size: 0,
    kernel_size: 0,
    initrd_size: 0,
};

#[link_section = ".startup"]
#[no_mangle]
fn stage2() {
    let kernel_size: u16;
    let stage3_size: u16;
    let stage4_size: u16;
    let initrd_size: u16;
    let cmd_line: &[u8];
    unsafe {
        kernel_size = PARAM.kernel_size;
        stage3_size = PARAM.stage3_size;
        stage4_size = PARAM.stage4_size;
        initrd_size = PARAM.initrd_size;
        cmd_line = &PARAM.cmd_line;
    }
    let ptr = STAGE3_START as *const ();
    let stage3: extern "C" fn(u16, u16, &[u8]) -> ! = unsafe { core::mem::transmute(ptr) };
    let mbr = 0x000usize as *const DiskRecord;
    let mbr: &DiskRecord = unsafe { &*mbr };

    print!("\r\nStage2: ");
    println!(
        "stage3_4_size = {:04X} : \
              kernel_size = {:04X} : \
              initrd_size = {:04X}",
        stage3_size + stage4_size,
        kernel_size,
        initrd_size
    );

    mbr.load_images(stage3_size, stage4_size, kernel_size, initrd_size)
        .unwrap();
    stage3(kernel_size, initrd_size, cmd_line);
}

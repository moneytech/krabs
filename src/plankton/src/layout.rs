// memlayout
pub const INIT_SEG: u32 = 0x07C0;
pub const KERNEL_SIZE: u32 = 0x100;
pub const STAGE2_LOAD: u32 = 0x200;
pub const STAGE2_START: u32 = 0x280;
pub const STAGE3_START: u32 = 0x6000;
pub const TRACK_BUFFER: u32 = 0xB000;
pub const TRACK_BUF_SIZE: u32 = 0x4000;
pub const STACK_SIZE: i32 = 1024;
pub const PRE_CMDLINEAD: u32 = 0x8C00;
pub const CMD_LINE_ADDR: u32 = 0x0002_0000;
pub const STAGE4_START: u32 = 0x0003_0000;
pub const PGTABLE_START: u64 = 0x1000;
pub const ELF_START: u32 = 0x0010_0000;
pub const IMAGE_START: u32 = 0x0350_0000;
pub const INITRD_START: u32 = 0x0560_0000;
pub const HEAP_START: u32 = 0x0760_0000;
pub const HEAP_END: u32 = 0x07FF_FFFF;

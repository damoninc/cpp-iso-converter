#include "ciso.h"

#include <cstdint>
#include <fstream>
#include <limits>
#include <string>
#include <vector>

namespace ciso {
namespace {

constexpr std::uint32_t kCisoMagic = 0x4F534943;  // "CISO" little-endian
constexpr std::uint32_t kGameCubeDiscMagic = 0xC2339F3D;
constexpr std::uint32_t kHeaderSize = 0x8000;
constexpr std::uint64_t kGameCubeDiscSize = 1459978240ull;

struct GcCisoHeader {
    std::uint32_t magic;
    std::uint32_t block_size;
};

bool read_header(std::ifstream& input, GcCisoHeader& header) {
    input.read(reinterpret_cast<char*>(&header), sizeof(header));
    return input.good();
}

std::vector<std::uint8_t> read_block_map(std::ifstream& input, std::uint64_t block_count) {
    std::vector<std::uint8_t> block_map(block_count);
    input.read(reinterpret_cast<char*>(block_map.data()),
               static_cast<std::streamsize>(block_map.size()));
    if (!input) {
        throw std::runtime_error("input file ended while reading the block map");
    }
    return block_map;
}

ConvertResult run_conversion(const std::filesystem::path& input_path,
                             const std::filesystem::path& output_path) {
    std::ifstream input(input_path, std::ios::binary);
    if (!input) {
        return {false, "could not open input file: " + input_path.string()};
    }

    GcCisoHeader header{};
    if (!read_header(input, header)) {
        return {false, "input file is too small to contain a CISO header"};
    }
    if (header.magic != kCisoMagic) {
        return {false, "invalid CISO header magic"};
    }
    if (header.block_size == 0) {
        return {false, "invalid CISO block size"};
    }
    if ((header.block_size & (header.block_size - 1)) != 0) {
        return {false, "CISO block size must be a power of two"};
    }
    if (header.block_size < 0x8000) {
        return {false, "CISO block size is too small for the GameCube variant"};
    }

    const std::uint64_t block_count =
        (kGameCubeDiscSize + header.block_size - 1) / header.block_size;

    input.seekg(sizeof(header), std::ios::beg);
    std::vector<std::uint8_t> block_map;
    try {
        block_map = read_block_map(input, block_count);
    } catch (const std::exception& ex) {
        return {false, ex.what()};
    }

    std::uint64_t stored_block_count = 0;
    for (const std::uint8_t entry : block_map) {
        if (entry > 1) {
            return {false, "unsupported block map entry in GameCube CISO"};
        }
        stored_block_count += entry;
    }

    const std::uint64_t expected_file_size =
        kHeaderSize + (stored_block_count * static_cast<std::uint64_t>(header.block_size));
    input.seekg(0, std::ios::end);
    const std::uint64_t actual_file_size = static_cast<std::uint64_t>(input.tellg());
    if (actual_file_size < expected_file_size) {
        return {false, "file is too small for the GameCube CISO block map"};
    }

    input.seekg(kHeaderSize, std::ios::beg);
    std::vector<char> first_block(static_cast<std::size_t>(header.block_size));
    input.read(first_block.data(), static_cast<std::streamsize>(first_block.size()));
    if (!input) {
        return {false, "input file ended before the first data block"};
    }
    const std::uint32_t disc_magic = static_cast<std::uint32_t>(
        (static_cast<std::uint32_t>(static_cast<unsigned char>(first_block[0x1c])) << 24) |
        (static_cast<std::uint32_t>(static_cast<unsigned char>(first_block[0x1d])) << 16) |
        (static_cast<std::uint32_t>(static_cast<unsigned char>(first_block[0x1e])) << 8) |
        static_cast<std::uint32_t>(static_cast<unsigned char>(first_block[0x1f])));
    if (disc_magic != kGameCubeDiscMagic) {
        return {false, "only the GameCube CISO variant is supported"};
    }
    input.seekg(kHeaderSize, std::ios::beg);

    std::ofstream output(output_path, std::ios::binary | std::ios::trunc);
    if (!output) {
        return {false, "could not open output file: " + output_path.string()};
    }

    std::vector<char> zero_block(static_cast<std::size_t>(header.block_size), 0);
    std::vector<char> data_block(static_cast<std::size_t>(header.block_size));

    for (std::uint64_t block = 0; block < block_count; ++block) {
        const std::uint64_t block_offset = block * static_cast<std::uint64_t>(header.block_size);
        const std::uint64_t remaining_output = kGameCubeDiscSize - block_offset;
        const std::size_t output_block_size = static_cast<std::size_t>(
            remaining_output < header.block_size ? remaining_output : header.block_size);

        if (block_map[static_cast<std::size_t>(block)] == 0) {
            output.write(zero_block.data(), static_cast<std::streamsize>(output_block_size));
        } else {
            input.read(data_block.data(), static_cast<std::streamsize>(header.block_size));
            if (!input) {
                return {false, "input file ended while reading a stored block"};
            }
            output.write(data_block.data(), static_cast<std::streamsize>(output_block_size));
        }

        if (!output) {
            return {false, "failed while writing output ISO"};
        }
    }

    return {true, "conversion complete (GameCube CISO)"};
}

}  // namespace

ConvertResult convert_to_iso(const std::filesystem::path& input_path,
                             const std::filesystem::path& output_path) {
    return run_conversion(input_path, output_path);
}

}  // namespace ciso

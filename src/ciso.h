#pragma once

#include <filesystem>
#include <string>

namespace ciso {

struct ConvertResult {
    bool ok;
    std::string message;
};

ConvertResult convert_to_iso(const std::filesystem::path& input_path,
                             const std::filesystem::path& output_path);

}  // namespace ciso

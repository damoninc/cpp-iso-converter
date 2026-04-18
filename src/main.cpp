#include "ciso.h"

#include <iostream>

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: ciso2iso <input.cso> <output.iso>\n";
        return 1;
    }

    const ciso::ConvertResult result = ciso::convert_to_iso(argv[1], argv[2]);
    if (!result.ok) {
        std::cerr << "Error: " << result.message << '\n';
        return 1;
    }

    std::cout << result.message << '\n';
    return 0;
}

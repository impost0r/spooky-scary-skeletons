//shim for external hakes

import std.stdio;
import core.sys.windows.windows;
import core.sys.windows.tlhelp32;
import std.process;
import std.conv;
import std.format;

private
__gshared size_t _mainModule;

private
__gshared uint _processID;

private
__gshared void *_windowHandle;

/// Attach to a game process.
void attach()
{
	HWND windowHandle = FindWindow(null, "Deep Rock Galactic ");
	_windowHandle = windowHandle;
	DWORD pid;
	GetWindowThreadProcessId(windowHandle, &pid);
	_processID = pid;

	auto snapshot = enforceWin32!(CreateToolhelp32Snapshot, "a != INVALID_HANDLE_VALUE")(TH32CS_SNAPMODULE, pid);
	scope(exit) CloseHandle(snapshot);

	MODULEENTRY32 moduleEntry;
	moduleEntry.dwSize = moduleEntry.sizeof;
	enforceWin32!Module32First(snapshot, &moduleEntry);

	_mainModule = cast(size_t) moduleEntry.modBaseAddr;
	writefln("human readable base: %x", mainModule);
}

/// Get the main module base address.
size_t mainModule() @property
{
	return _mainModule;
}

void *windowHandle() @property
{
	return _windowHandle;
}

uint processID() @property
{
	return _processID;
}

/// Read bytes from the game process into a byte array.
void read(size_t address, void* bytes, size_t length)
{
    enforceWin32!Toolhelp32ReadProcessMemory(processID, cast(const(void)*) address, bytes, length, null);
}

/// Open process, write memory
void write(void* address, void* bytes, size_t length)
{
	enforceWin32!OpenProcess(PROCESS_ALL_ACCESS, FALSE, processID);
	enforceWin32!WriteProcessMemory(windowHandle, address, cast(const(void)*) bytes, length, null);
}

/// Read a value from the game process.
T read(T)(size_t address)
{
    T value;
    read(address, &value, value.sizeof);
    return value;
}

/// Write memory
T write(T)(size_t address)
{
	T value;
	write(address, &value, value.sizeof);
	return value;
}


/// Throw an exception if Check is false with the result of Windows API function Function when called with args.
auto enforceWin32(alias Function, alias Check = "a", string file = __FILE__, size_t line = __LINE__, Args...)(Args args)@system
{
	auto a = Function(args);
	if (!mixin(Check))
	{
		throw new Exception("Error occured -- report to developer");
	}
	return a;
}

void main()
{
	attach();
	auto address = read!size_t(mainModule);

}

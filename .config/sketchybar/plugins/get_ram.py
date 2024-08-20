#!/opt/homebrew/opt/python@3.11/libexec/bin/python
import psutil

# Getting % usage of virtual_memory (3rd field)
print(f"{psutil.virtual_memory()[2]}%")

# Getting usage of virtual_memory in GB (4th field)
print(f"{round(psutil.virtual_memory()[3] / 1000000000, 2)}GB")

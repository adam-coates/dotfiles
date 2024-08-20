#!/opt/homebrew/opt/python@3.11/libexec/bin/python

import speedtest


def perform_speed_test():
   st = speedtest.Speedtest()
   download_speed = st.download() / 1000000  # Convert to Mbps

   return download_speed

if __name__ == "__main__":
   download_speed = perform_speed_test()
   print("{:.2f} Mbps".format(download_speed))

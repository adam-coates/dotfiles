#!/opt/homebrew/Cellar/python@3.11/3.11.8/bin/python3.11
import speedtest

def perform_speed_test():
   st = speedtest.Speedtest()
   download_speed = st.download() / 1000000  # Convert to Mbps

   return download_speed

if __name__ == "__main__":
   download_speed = perform_speed_test()
   print("{:.2f} Mbps".format(download_speed))

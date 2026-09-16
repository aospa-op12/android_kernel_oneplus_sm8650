ifeq ($(CONFIG_OPLUS_SENSOR_MAG_MATCH_NFC), y)
CFLAGS_oplus_sensor_devinfo.o += -DOPLUS_FEATURE_SENSOR_MAG_MATCH_NFC
endif
oplus_sensor-y := oplus_sensor_devinfo.o
oplus_sensor-y += oplus_press_cali_info.o
oplus_sensor-y += oplus_pad_als_info.o
oplus_sensor_deviceinfo-y := $(oplus_sensor-y)
obj-m += oplus_sensor_deviceinfo.o
obj-y += oplus_ssc_interact/
obj-y += oplus_sensor_feedback/

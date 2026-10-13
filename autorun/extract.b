python -c "open('dump-totale.bin', 'wb').write(open('1000-nema.bin', 'rb').read()[0x10000:0x10000+0x1FE000])"

pause
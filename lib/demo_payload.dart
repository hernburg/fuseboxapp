const demoPayload = {
  "settings": {"phases": 1, "mainBreakerA": 63, "railWidthModules": 12, "voltageStd": 220},
  "devices": {"voltageRelay": true, "spdClass2": false, "afdd": false, "contactor": false, "meter": false, "dinSocket": false, "fireRCD": true, "nonDisconnectable": false},
  "grouping": {"perGroup": {"sockets": 2, "lights": 2, "hvac": 1}, "perFloorOverride": false, "floorRCD": false},
  "floors": [
    {"title": "Этаж 1", "rooms": [
      {"title": "Кухня", "sockets": 6, "lights": 2, "hvac": 1},
      {"title": "С/У",   "sockets": 2, "lights": 1, "hvac": 0, "wet": true}
    ]}
  ]
};
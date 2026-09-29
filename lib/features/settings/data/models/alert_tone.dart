enum AlertTone {
  electronicOne,
  electronicTwo,
  electronicThree;

  String get storageValue => switch (this) {
    AlertTone.electronicOne => 'electronic_one',
    AlertTone.electronicTwo => 'electronic_two',
    AlertTone.electronicThree => 'electronic_three',
  };

  String get title => switch (this) {
    AlertTone.electronicOne => 'Alerta eletrônico 1',
    AlertTone.electronicTwo => 'Alerta eletrônico 2',
    AlertTone.electronicThree => 'Alerta eletrônico 3',
  };

  String get description => switch (this) {
    AlertTone.electronicOne => 'error.mp3',
    AlertTone.electronicTwo => 'error2.mp3',
    AlertTone.electronicThree => 'error3.mp3',
  };

  String get assetPath => switch (this) {
    AlertTone.electronicOne => 'audio/error.mp3',
    AlertTone.electronicTwo => 'audio/error2.mp3',
    AlertTone.electronicThree => 'audio/error3.mp3',
  };

  static AlertTone fromStorage(String? value) => switch (value) {
    'electronic_two' => AlertTone.electronicTwo,
    'electronic_three' => AlertTone.electronicThree,
    // Valores das versões anteriores migram para o primeiro som novo.
    _ => AlertTone.electronicOne,
  };
}

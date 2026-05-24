import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class AwsCredentials {
  String? awsAccessKeyId;
  String? awsSecretAccessKey;
  String? awsSessionToken;
  Map<String, String>? environment;
  Map<String, String>? containerCredentials;

  AwsCredentials(
      {this.awsAccessKeyId,
      this.awsSecretAccessKey,
      this.awsSessionToken,
      this.environment,
      this.containerCredentials}) {

    final env = environment ?? Platform.environment;
    environment ??= Platform.environment;
    awsAccessKeyId = awsAccessKeyId ?? env['AWS_ACCESS_KEY_ID'];
    awsSecretAccessKey = awsSecretAccessKey ?? env['AWS_SECRET_ACCESS_KEY'];

    if (containerCredentials != null &&
        awsAccessKeyId == null &&
        awsSecretAccessKey == null) {
      awsAccessKeyId = containerCredentials!['AccessKeyId'];
      awsSecretAccessKey = containerCredentials!['SecretAccessKey'];
      awsSessionToken = containerCredentials!['Token'];
    }

    if (awsAccessKeyId == null || awsSecretAccessKey == null) {
      throw ArgumentError(
          'You must provide a valid Access Key and Secret for AWS.');
    }
  }

  Future<Map<String, String>?> getContainerCredentials(
      Map<String, String> environment) async {
    try {
      final relativeUri =
          environment['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'] ?? '';
      final url = Uri.parse('http://169.254.170.2$relativeUri');
      final response = await http.read(url);
      return json.decode(response) as Map<String, String>?;
    } catch (e) {
      print('failed to get container credentials.');
    }
    return null;
  }
}

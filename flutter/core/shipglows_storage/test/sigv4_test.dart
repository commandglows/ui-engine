import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_storage/shipglows_storage.dart';

/// Vectors from the AWS SigV4 test suite and the S3 documentation.
void main() {
  test('aws-sig-v4-test-suite get-vanilla', () {
    const signer = SigV4Signer(
      credentials: (
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
      ),
      region: 'us-east-1',
      service: 'service',
    );
    final headers = signer.sign(
      method: 'GET',
      path: '/',
      headers: const {'Host': 'example.amazonaws.com'},
      payloadHash: emptyPayloadHash,
      now: DateTime.utc(2015, 8, 30, 12, 36),
      signContentHash: false,
    );
    expect(headers['x-amz-date'], '20150830T123600Z');
    expect(
      headers['Authorization'],
      'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/'
      'aws4_request, SignedHeaders=host;x-amz-date, Signature='
      '5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31',
    );
  });

  test('S3 documentation GET object with Range', () {
    const signer = SigV4Signer(
      credentials: (
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      ),
      region: 'us-east-1',
    );
    final headers = signer.sign(
      method: 'GET',
      path: '/test.txt',
      headers: const {
        'host': 'examplebucket.s3.amazonaws.com',
        'range': 'bytes=0-9',
      },
      payloadHash: emptyPayloadHash,
      now: DateTime.utc(2013, 5, 24),
    );
    expect(
      headers['Authorization'],
      endsWith('Signature='
          'f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41'),
    );
  });

  test('S3 documentation ListObjects with query', () {
    const signer = SigV4Signer(
      credentials: (
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      ),
      region: 'us-east-1',
    );
    final headers = signer.sign(
      method: 'GET',
      path: '/',
      query: const {'max-keys': '2', 'prefix': 'J'},
      headers: const {'host': 'examplebucket.s3.amazonaws.com'},
      payloadHash: emptyPayloadHash,
      now: DateTime.utc(2013, 5, 24),
    );
    expect(
      headers['Authorization'],
      endsWith('Signature='
          '34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7'),
    );
  });

  test('keys are encoded once with slashes kept', () {
    expect(canonicalPath('/b/dossier/été 1.mp3'),
        '/b/dossier/%C3%A9t%C3%A9%201.mp3');
    expect(canonicalQuery({'uploads': '', 'a b': 'c/d'}), 'a%20b=c%2Fd&uploads=');
  });
}

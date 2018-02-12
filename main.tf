provider "aws" { 
    region = "${var.AWS_REGION}"
}
##createion of 1st bucket
resource "aws_s3_bucket" "my-source-test-bucket" {
  bucket = "my-source-test-bucket"
  acl    = "public-read"

  tags {
    Name  = "my-suurce-test-bucket"
    Environment = "test"
  }
}
#Creation of 2nd bucket

resource "aws_s3_bucket" "my-source-test-bucket-resized" {
  bucket = "my-source-test-bucket-resized"
  acl    = "private"

  tags {
    Name  = "my-source-test-bucket-resized"
    Environment = "test"
  }
}
## IAM Role for lambda

resource "aws_iam_role" "iam_for_terraform_lambda" {
    name = "kinesis_streamer_iam_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}
resource "aws_iam_policy" "s3-bucket-policy" {
    name = "s3-bucket-policy"
    description = "A test policy"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "test-attach" {
    role       = "${aws_iam_role.iam_for_terraform_lambda.name}"
    policy_arn = "${aws_iam_policy.s3-bucket-policy.arn}"
}
##Lambda Function Creation

resource "aws_lambda_function" "Create-Thumbnail" {
  filename         = "CreateThumbnail.zip"
  function_name    = "Create-Thumbnail"
  role             = "${aws_iam_role.iam_for_terraform_lambda.arn}"
  handler          = "CreateThumbnail.handler"
  source_code_hash = "${base64sha256(file("CreateThumbnail.zip"))}"
  runtime          = "python3.6"

  environment {
    variables = {
      foo = "bar"
    }
  }
}
## Add S3 trigger
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.Create-Thumbnail.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.my-source-test-bucket.arn}"
}
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.my-source-test-bucket.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.Create-Thumbnail.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".log"
  }
}

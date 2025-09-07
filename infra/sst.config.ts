// deno-lint-ignore-file no-explicit-any
/// <reference path="./.sst/platform/config.d.ts" />

// the function name matching the cargo lambda deploy step,
// by default binary name in kebab-case (underscores not allowed)
// TODO get these from Cargo.toml/beet.toml
const appName = "mrchantey-os";
// the production stage has no prefix and extra protections
// against removal
const prodStage = "prod";
const bucketName = appName;

export default $config({
  app(input) {
    return {
      name: appName,
      removal: input?.stage === prodStage ? "retain" : "remove",
      // protect: [prodStage].includes(input?.stage),
      home: "aws",
      providers: {
        aws: {
          region: "us-west-2",
        },
      },
    };
  },
  run() {
    const _bucket = new sst.aws.Bucket(bucketName, {
      name: bucketName,
      access: "public",
      versioned: true,
      transform: {
        bucket: (args: any) => {
          // override the actual resource name
          args.bucket = bucketName;
        },
      },
    });
  },
});

OC_CI_NODEJS = "opencloud-eu/nodejs:18"
OC_CI_BAZEL_BUILDIFIER = "opencloud-eu/bazel-buildifier"
OC_CI_ALPINE = "opencloud-eu/alpine:latest"

PLUGINS_GITHUB_RELEASE = "plugins/github-release:1"

def main(ctx):
    before = beforePipelines(ctx)

    stages = pipelinesDependsOn(stagePipelines(ctx), before)
    if (stages == False):
        print("Errors detected. Review messages above.")
        return []

    after = pipelinesDependsOn(afterPipelines(ctx), stages)

    pipelines = before + stages + after

    return pipelines

def determineReleaseVersion(ctx):
    if ctx.build.event != "tag":
        return None

    return ctx.build.ref.replace("refs/tags/v", "")

def installPnpm():
    return [{
        "name": "pnpm-install",
        "image": OC_CI_NODEJS,
        "commands": [
            'npm install --silent --global --force "$(jq -r ".packageManager" < package.json)"',
            "pnpm config set store-dir ./.pnpm-store",
            "pnpm install",
        ],
    }]

def webLint():
    return [{
        "name": "lint",
        "image": OC_CI_NODEJS,
        "depends_on": ["pnpm-install"],
        "commands": [
            "pnpm lint",
        ],
    }]

def webTypecheck():
    return [{
        "name": "typecheck",
        "image": OC_CI_NODEJS,
        "depends_on": ["pnpm-install"],
        "commands": [
            "pnpm check:types",
        ],
    }]

def beforePipelines(ctx):
    return checkStarlark()

def stagePipelines(ctx):
    return checks(ctx) + unitTests(ctx)

def afterPipelines(ctx):
    return appBuilds(ctx)

def pipelineDependsOn(pipeline, dependant_pipelines):
    if "depends_on" in pipeline.keys():
        pipeline["depends_on"] = pipeline["depends_on"] + getPipelineNames(dependant_pipelines)
    else:
        pipeline["depends_on"] = getPipelineNames(dependant_pipelines)
    return pipeline

def pipelinesDependsOn(pipelines, dependant_pipelines):
    pipes = []
    for pipeline in pipelines:
        pipes.append(pipelineDependsOn(pipeline, dependant_pipelines))

    return pipes

def getPipelineNames(pipelines = []):
    """getPipelineNames returns names of pipelines as a string array

    Args:
      pipelines: array of drone pipelines

    Returns:
      names of the given pipelines as string array
    """
    names = []
    for pipeline in pipelines:
        names.append(pipeline["name"])
    return names

def checkStarlark():
    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "check-starlark",
        "steps": [
            {
                "name": "format-check-starlark",
                "image": OC_CI_BAZEL_BUILDIFIER,
                "commands": [
                    "buildifier --mode=check .drone.star",
                ],
            },
            {
                "name": "show-diff",
                "image": OC_CI_BAZEL_BUILDIFIER,
                "commands": [
                    "buildifier --mode=fix .drone.star",
                    "git diff",
                ],
                "when": {
                    "status": [
                        "failure",
                    ],
                },
            },
        ],
        "trigger": {
            "ref": [
                "refs/pull/**",
            ],
        },
    }]

def checks(ctx):
    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "lint+types",
        "steps": installPnpm() +
                 webLint() +
                 webTypecheck(),
        "trigger": {
            "ref": [
                "refs/heads/main",
                "refs/heads/stable-*",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }]

def unitTests(ctx):
    unit_test_steps = [{
        "name": "unit-tests-app",
        "image": OC_CI_NODEJS,
        "depends_on": ["pnpm-install"],
        "commands": [
            "pnpm test:unit",
        ],
    }]

    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "unit-tests",
        "steps": installPnpm() + unit_test_steps,
        "trigger": {
            "ref": [
                "refs/heads/main",
                "refs/heads/stable-*",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }]

def publishSteps(ctx):
    version = determineReleaseVersion(ctx)
    if version == None:
        return []

    return [{
        "name": "publish",
        "image": PLUGINS_GITHUB_RELEASE,
        "depends_on": ["package"],
        "settings": {
            "api_key": {
                "from_secret": "github_token",
            },
            "files": [
                "assets/skeleton-%s.zip" % version,
            ],
            "checksum": [
                "md5",
                "sha256",
            ],
            "title": "skeleton %s" % version,
            "note": ".release_note",
            "overwrite": True,
        },
        "when": {
            "ref": [
                "refs/tags/**",
            ],
        },
    }]

def appBuilds(ctx):
    version = determineReleaseVersion(ctx)
    if version == None:
        return []

    app_build_steps = [{
        "name": "build",
        "image": OC_CI_NODEJS,
        "depends_on": ["pnpm-install"],
        "commands": [
            "pnpm build",
        ],
    }, {
        "name": "package",
        "image": OC_CI_ALPINE,
        "depends_on": ["build"],
        "commands": [
            "apk add zip",
            "mkdir -p assets/skeleton/",
            "cp -R .vscode dev public src tests assets/skeleton/",
            "cp .editorconfig .eslintrc.json .gitignore .npmrc .prettierrc.json docker-compose.yml LICENSE package.json pnpm-lock.yaml README.md tsconfig.json vite.config.ts assets/skeleton/",
            "cd assets/",
            "zip -r skeleton-%s.zip skeleton/" % version,
        ],
        "when": {
            "ref": [
                "refs/tags/**",
            ],
        },
    }]

    return [{
        "kind": "pipeline",
        "type": "docker",
        "name": "build",
        "steps": installPnpm() + app_build_steps + publishSteps(ctx),
        "trigger": {
            "ref": [
                "refs/heads/main",
                "refs/heads/stable-*",
                "refs/tags/**",
                "refs/pull/**",
            ],
        },
    }]

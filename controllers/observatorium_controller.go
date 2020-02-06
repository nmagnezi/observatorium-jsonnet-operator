/*

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	obsapiv1alpha1 "github.com/nmagnezi/observatorium-jsonnet-operator/api/v1alpha1"

	"k8s.io/client-go/kubernetes"

	lclient "github.com/brancz/locutus/client"
	"github.com/brancz/locutus/config"
	"github.com/brancz/locutus/render"
	"github.com/brancz/locutus/rollout"
	"github.com/brancz/locutus/rollout/checks"
	"github.com/brancz/locutus/trigger"
	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/oklog/run"
	"github.com/pkg/errors"
)

// ObservatoriumReconciler reconciles a Observatorium object
type ObservatoriumReconciler struct {
	client.Client
	Log    logr.Logger
	Scheme *runtime.Scheme
}

const (
	logLevelAll   = "all"
	logLevelDebug = "debug"
	logLevelInfo  = "info"
	logLevelWarn  = "warn"
	logLevelError = "error"
	logLevelNone  = "none"
)

var (
	availableLogLevels = []string{
		logLevelAll,
		logLevelDebug,
		logLevelInfo,
		logLevelWarn,
		logLevelError,
		logLevelNone,
	}
)

// +kubebuilder:rbac:groups=obs-api.observatorium.io,resources=observatoria,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=obs-api.observatorium.io,resources=observatoria/status,verbs=get;update;patch

func (r *ObservatoriumReconciler) Reconcile(req ctrl.Request) (ctrl.Result, error) {
	_ = context.Background()
	olog := r.Log.WithValues("observatorium", req.NamespacedName)
	olog.Info("TEST TEST TEST")

	var (
		logLevel            = logLevelInfo
		renderProviderName  = "jsonnet"
		triggerProviderName = "oneoff"
		configFile          = "jsonnet/main/default-config.libsonnet"
		renderOnly          = false
	)

	renderers := render.Providers()
	triggers := trigger.Providers()
	args := []string{"--renderer.jsonnet.entrypoint=jsonnet/main/main.jsonnet"}

	s := flag.NewFlagSet(os.Args[0], flag.ContinueOnError)
	renderers.RegisterFlags(s)
	triggers.RegisterFlags(s)
	s.Parse(args)

	logger, err := logger(logLevel)
	if err != nil {
		logger.Log("msg", "error creating logger", err)
	}

	cfg := ctrl.GetConfigOrDie()

	kclient, err := kubernetes.NewForConfig(cfg)
	if err != nil {
		logger.Log("msg", "error building kubeconfig", "err", err)
	}

	cl := lclient.NewClient(log.With(logger, "component", "client"), cfg, kclient)
	if err != nil {
		logger.Log("msg", "failed to instantiate client", "err", err)
		return ctrl.Result{}, err
	}
	cl.SetUpdatePreparations(lclient.DefaultUpdatePreparations)

	renderProvider, err := renderers.Select(renderProviderName)
	if err != nil {
		logger.Log("msg", "failed to find render provider", "err", err)
		return ctrl.Result{}, err
	}

	triggerProvider, err := triggers.Select(triggerProviderName)
	if err != nil {
		logger.Log("msg", "failed to find trigger provider", "err", err)
		return ctrl.Result{}, err
	}

	trigger, err := triggerProvider.NewTrigger(logger, cl)
	if err != nil {
		logger.Log("msg", "failed to create trigger", "err", err)
		return ctrl.Result{}, err
	}

	c := checks.NewSuccessChecks(logger, cl)
	renderer := renderProvider.NewRenderer(logger)
	runner := rollout.NewRunner(nil, log.With(logger, "component", "rollout-runner"), cl, renderer, c, renderOnly)
	runner.SetObjectActions(rollout.DefaultObjectActions)
	trigger.Register(config.NewConfigPasser(configFile, runner))

	g := run.Group{}

	ctx, cancel := context.WithCancel(context.Background())
	g.Add(func() error {
		return errors.Wrap(trigger.Run(ctx.Done()), "failed to run trigger")
	}, func(err error) {
		cancel()
	})

	term := make(chan os.Signal)
	g.Add(func() error {
		signal.Notify(term, os.Interrupt, syscall.SIGTERM)

		select {
		case <-term:
			return nil
		}

	}, func(err error) {
		close(term)
	})

	if err := g.Run(); err != nil {
		logger.Log("msg", "Unhandled error received. Exiting...", "err", err)
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *ObservatoriumReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&obsapiv1alpha1.Observatorium{}).
		Complete(r)
}

func logger(logLevel string) (log.Logger, error) {
	logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	switch logLevel {
	case logLevelAll:
		logger = level.NewFilter(logger, level.AllowAll())
	case logLevelDebug:
		logger = level.NewFilter(logger, level.AllowDebug())
	case logLevelInfo:
		logger = level.NewFilter(logger, level.AllowInfo())
	case logLevelWarn:
		logger = level.NewFilter(logger, level.AllowWarn())
	case logLevelError:
		logger = level.NewFilter(logger, level.AllowError())
	case logLevelNone:
		logger = level.NewFilter(logger, level.AllowNone())
	default:
		return nil, fmt.Errorf("log level %v unknown, %v are possible values", logLevel, availableLogLevels)
	}
	logger = log.With(logger, "ts", log.DefaultTimestampUTC)
	logger = log.With(logger, "caller", log.DefaultCaller)

	return logger, nil
}

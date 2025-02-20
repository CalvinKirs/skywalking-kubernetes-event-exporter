/*
 * Licensed to Apache Software Foundation (ASF) under one or more contributor
 * license agreements. See the NOTICE file distributed with
 * this work for additional information regarding copyright
 * ownership. Apache Software Foundation (ASF) licenses this file to you under
 * the Apache License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package k8s

import (
	v1 "k8s.io/api/core/v1"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/cache"

	"github.com/apache/skywalking-kubernetes-event-exporter/internal/pkg/logger"
)

type EventWatcher struct {
	Events   chan *v1.Event
	informer cache.SharedIndexInformer
	stopCh   chan struct{}
}

func (w EventWatcher) OnAdd(obj interface{}) {
	w.Events <- obj.(*v1.Event)
}

func (w EventWatcher) OnUpdate(_, newObj interface{}) {
	w.Events <- newObj.(*v1.Event)
}

func (w EventWatcher) OnDelete(_ interface{}) {
}

func (w EventWatcher) Start() {
	logger.Log.Debugf("starting event watcher")

	go w.informer.Run(w.stopCh)
}

func (w EventWatcher) Stop() {
	logger.Log.Debugf("stopping event watcher")

	w.stopCh <- struct{}{}
	close(w.stopCh)
}

func WatchEvents(ns string) (*EventWatcher, error) {
	config, err := GetConfig()
	if err != nil {
		return nil, err
	}
	client := kubernetes.NewForConfigOrDie(config)
	factory := informers.NewSharedInformerFactoryWithOptions(client, 0, informers.WithNamespace(ns))
	informer := factory.Core().V1().Events().Informer()

	watcher := &EventWatcher{
		informer: informer,
		Events:   make(chan *v1.Event),
		stopCh:   make(chan struct{}),
	}

	informer.AddEventHandler(watcher)

	return watcher, nil
}

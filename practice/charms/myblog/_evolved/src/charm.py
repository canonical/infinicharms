#!/usr/bin/env python3
# Copyright 2026 Ubuntu
# See LICENSE file for licensing details.

"""Charm the application."""

import ops


class MyblogEvolvedCharm(ops.CharmBase):
    """Charm the application."""

    def __init__(self, framework: ops.Framework):
        super().__init__(framework)
        framework.observe(self.on.install, self._on_install)
        framework.observe(self.on.start, self._on_start)
        framework.observe(self.on.config_changed, self._on_config_changed)
        framework.observe(self.on.update_status, self._on_update_status)
        framework.observe(self.on.upgrade_charm, self._on_upgrade_charm)
        framework.observe(self.on.collect_unit_status, self._on_collect_unit_status)
        framework.observe(self.on["database"].relation_joined, self._on_database_relation_joined)
        framework.observe(self.on["database"].relation_changed, self._on_database_relation_changed)
        framework.observe(
            self.on["database"].relation_departed, self._on_database_relation_departed
        )
        framework.observe(self.on.webserver.pebble_ready, self._on_webserver_pebble_ready)

    def _on_install(self, event: ops.InstallEvent) -> None:
        pass

    def _on_start(self, event: ops.StartEvent) -> None:
        pass

    def _on_config_changed(self, event: ops.ConfigChangedEvent) -> None:
        pass

    def _on_update_status(self, event: ops.UpdateStatusEvent) -> None:
        pass

    def _on_upgrade_charm(self, event: ops.UpgradeCharmEvent) -> None:
        pass

    def _on_collect_unit_status(self, event: ops.CollectStatusEvent) -> None:
        pass

    def _on_database_relation_joined(self, event: ops.RelationEvent) -> None:
        pass

    def _on_database_relation_changed(self, event: ops.RelationEvent) -> None:
        pass

    def _on_database_relation_departed(self, event: ops.RelationEvent) -> None:
        pass

    def _on_webserver_pebble_ready(self, event: ops.PebbleReadyEvent) -> None:
        pass


if __name__ == "__main__":  # pragma: nocover
    ops.main(MyblogEvolvedCharm)

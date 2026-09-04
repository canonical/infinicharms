"""Charm the application."""

import ops


class AppleblogEvolvedCharm(ops.CharmBase):
    """Charm the application."""

    def __init__(self, *args):
        super().__init__(*args)
        self.framework.observe(self.on.install, self._on_install)
        self.framework.observe(self.on.start, self._on_start)
        self.framework.observe(self.on.config_changed, self._on_config_changed)
        self.framework.observe(self.on.update_status, self._on_update_status)
        self.framework.observe(self.on.upgrade_charm, self._on_upgrade_charm)
        self.framework.observe(self.on.collect_unit_status, self._on_collect_unit_status)

        # Relation observers for each requires relation.
        self.framework.observe(
            self.on["database"].relation_joined, self._on_database_relation_joined
        )
        self.framework.observe(
            self.on["database"].relation_changed, self._on_database_relation_changed
        )
        self.framework.observe(
            self.on["database"].relation_departed,
            self._on_database_relation_departed,
        )

        # Pebble-ready observers for each container.
        self.framework.observe(
            self.on["web-server"].pebble_ready, self._on_web_server_pebble_ready
        )

    def _on_install(self, event: ops.InstallEvent):
        pass

    def _on_start(self, event: ops.StartEvent):
        pass

    def _on_config_changed(self, event: ops.ConfigChangedEvent):
        pass

    def _on_update_status(self, event: ops.UpdateStatusEvent):
        pass

    def _on_upgrade_charm(self, event: ops.UpgradeCharmEvent):
        pass

    def _on_collect_unit_status(self, event: ops.CollectStatusEvent):
        pass

    def _on_database_relation_joined(self, event: ops.RelationJoinedEvent):
        pass

    def _on_database_relation_changed(self, event: ops.RelationChangedEvent):
        pass

    def _on_database_relation_departed(self, event: ops.RelationDepartedEvent):
        pass

    def _on_web_server_pebble_ready(self, event: ops.PebbleReadyEvent):
        pass


if __name__ == "__main__":
    ops.main(AppleblogEvolvedCharm)

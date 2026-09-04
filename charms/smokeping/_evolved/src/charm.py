"""Charm the application."""

import ops


class SmokepingEvolvedCharm(ops.CharmBase):
    """Charm the application."""

    def __init__(self, framework):
        super().__init__(framework)
        self.framework.observe(self.on.install, self._on_install)
        self.framework.observe(self.on.start, self._on_start)
        self.framework.observe(self.on.config_changed, self._on_config_changed)
        self.framework.observe(self.on.update_status, self._on_update_status)
        self.framework.observe(self.on.upgrade_charm, self._on_upgrade_charm)
        self.framework.observe(self.on.collect_unit_status, self._on_collect_unit_status)

    def _on_install(self, event):
        pass

    def _on_start(self, event):
        pass

    def _on_config_changed(self, event):
        pass

    def _on_update_status(self, event):
        pass

    def _on_upgrade_charm(self, event):
        pass

    def _on_collect_unit_status(self, event):
        pass


if __name__ == "__main__":
    ops.main(SmokepingEvolvedCharm)

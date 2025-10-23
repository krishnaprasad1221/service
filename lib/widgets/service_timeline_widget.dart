import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ServiceTimelineWidget extends StatefulWidget {
  final String status;
  final DateTime? bookedAt;
  final DateTime? acceptedAt;
  final DateTime? onTheWayAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final DateTime? paymentRequestedAt;
  final DateTime? paidAt;
  final bool? onTime;
  final int? estimatedDurationDays;
  final DateTime? expectedCompletionAt;

  const ServiceTimelineWidget({
    super.key,
    required this.status,
    this.bookedAt,
    this.acceptedAt,
    this.onTheWayAt,
    this.arrivedAt,
    this.completedAt,
    this.paymentRequestedAt,
    this.paidAt,
    this.onTime,
    this.estimatedDurationDays,
    this.expectedCompletionAt,
  });

  @override
  State<ServiceTimelineWidget> createState() => _ServiceTimelineWidgetState();
}

class _ServiceTimelineWidgetState extends State<ServiceTimelineWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(widget.status.toLowerCase());
    final currentIndex = _currentIndex(widget.status.toLowerCase());
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.timeline, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text('Service Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            if ((widget.onTime ?? false) && widget.status.toLowerCase() == 'on_the_way')
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: const [
                    Icon(Icons.directions_car, size: 16, color: Colors.deepPurple),
                    SizedBox(width: 6),
                    Expanded(child: Text('Provider is on the way', style: TextStyle(fontSize: 12, color: Colors.deepPurple))),
                  ],
                ),
              ),
            if ((widget.status.toLowerCase() == 'pending') && (widget.onTime != true) && (widget.estimatedDurationDays != null) && (widget.estimatedDurationDays! > 0))
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Service provider will reach your location within ${widget.estimatedDurationDays} working day${widget.estimatedDurationDays == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.expectedCompletionAt != null &&
                (widget.status.toLowerCase() != 'completed' && widget.status.toLowerCase() != 'paid'))
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Expected completion: ' + DateFormat.yMMMd().add_jm().format(widget.expectedCompletionAt!),
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            ...List.generate(steps.length, (i) {
              final s = steps[i];
              final reached = s.reached;
              final isCurrent = i == currentIndex;
              final isLast = i == steps.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      _StatusDot(
                        reached: reached,
                        isCurrent: isCurrent,
                        pulse: _pulse,
                        icon: s.icon,
                      ),
                      if (!isLast)
                        _Connector(
                          active: s.reached && steps[i + 1].reached,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: reached ? Colors.black87 : Colors.grey[600],
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Current', style: TextStyle(color: Colors.deepPurple, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        if (s.time != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              DateFormat.yMMMd().add_jm().format(s.time!),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        if (!isLast) const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  int _currentIndex(String st) {
    // Order: booked -> on_the_way -> arrived -> accepted -> completed -> payment_requested -> paid
    if (st == 'paid') return 6;
    if (st == 'payment_requested') return 5;
    if (st == 'completed') return 4;
    if (st == 'accepted') return 3;
    if (st == 'arrived') return 2;
    if (st == 'on_the_way') return 1;
    return 0; // pending / booked
  }

  List<_TimelineStep> _buildSteps(String st) {
    // Consider a booking always reached if we're rendering a timeline for it
    final bookedReached = true;
    final onTheWayReached = st == 'on_the_way' || st == 'arrived' || st == 'accepted' || st == 'completed' || st == 'payment_requested' || st == 'paid';
    final arrivedReached = st == 'arrived' || st == 'accepted' || st == 'completed' || st == 'payment_requested' || st == 'paid';
    final acceptedReached = st == 'accepted' || st == 'completed' || st == 'payment_requested' || st == 'paid';
    final completedReached = st == 'completed' || st == 'payment_requested' || st == 'paid';
    final payReqReached = st == 'payment_requested' || st == 'paid';
    final paidReached = st == 'paid';

    return [
      _TimelineStep(title: 'Booked', reached: bookedReached, time: widget.bookedAt, icon: Icons.event_note),
      _TimelineStep(title: 'On the Way', reached: onTheWayReached, time: widget.onTheWayAt, icon: Icons.directions_car),
      _TimelineStep(title: 'Arrived', reached: arrivedReached, time: widget.arrivedAt, icon: Icons.place),
      _TimelineStep(title: 'Accepted', reached: acceptedReached, time: widget.acceptedAt, icon: Icons.task_alt),
      _TimelineStep(title: 'Completed', reached: completedReached, time: widget.completedAt, icon: Icons.check_circle),
      _TimelineStep(title: 'Payment Requested', reached: payReqReached, time: widget.paymentRequestedAt, icon: Icons.request_page),
      _TimelineStep(title: 'Paid', reached: paidReached, time: widget.paidAt, icon: Icons.payments),
    ];
  }
}

class _Connector extends StatelessWidget {
  final bool active;
  const _Connector({required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? [Colors.deepPurple, Colors.deepPurple]
              : [Colors.grey.shade300, Colors.grey.shade300],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool reached;
  final bool isCurrent;
  final Animation<double> pulse;
  final IconData icon;
  const _StatusDot({required this.reached, required this.isCurrent, required this.pulse, required this.icon});

  @override
  Widget build(BuildContext context) {
    final baseColor = reached ? Colors.deepPurple : Colors.grey.shade400;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isCurrent)
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              return Container(
                width: 24 * pulse.value,
                height: 24 * pulse.value,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.18 * pulse.value),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: reached ? Colors.deepPurple : Colors.white,
            border: Border.all(color: baseColor, width: 2),
            shape: BoxShape.circle,
            boxShadow: [
              if (reached)
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Icon(icon, size: 10, color: reached ? Colors.white : baseColor),
        ),
      ],
    );
  }
}

class _TimelineStep {
  final String title;
  final bool reached;
  final DateTime? time;
  final IconData icon;
  _TimelineStep({required this.title, required this.reached, this.time, required this.icon});
}
